# EKS cluster + managed node group, the counterpart to gcp/gke.
#
# Two AWS-specific things have no GCP equivalent and are easy to miss:
#
#   1. IRSA. GKE has Workload Identity built in; on EKS you must create an OIDC
#      provider from the cluster and bind IAM roles to service accounts through
#      it. cert-manager's DNS-01 solver needs this to touch Route53.
#   2. The EBS CSI driver is NOT installed by default on recent EKS versions.
#      Without it every PVC stays Pending forever with no obvious cause — the
#      same class of failure as the minio WaitForFirstConsumer deadlock on GKE.

variable "cluster_name" { type = string }
variable "kubernetes_version" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "allowlist_cidr" { type = string }
variable "master_authorized_extra" { type = list(string) }
variable "storage_class" { type = string }

data "aws_partition" "current" {}

# ── Control plane ────────────────────────────────────────────────────────────
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    # Nodes live private; the API server is reachable from the allowlist only,
    # matching gcp's master_authorized_networks.
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = concat([var.allowlist_cidr], var.master_authorized_extra)
  }

  # Without this, `terraform destroy` leaves the cluster behind on some paths.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ── IRSA (the Workload Identity equivalent) ──────────────────────────────────
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}

# ── Node group ───────────────────────────────────────────────────────────────
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
    # Lets the EBS CSI driver create volumes for PVCs.
    "AmazonEBSCSIDriverPolicy",
  ])
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

# 2 x m5.xlarge ≈ the 2 x e2-standard-4 used on GKE. The whole mockten stack is
# ~21 pods; smaller instances hit the pods-per-node ENI limit before they run
# out of CPU, which presents as pods stuck Pending with no scheduling reason.
resource "aws_eks_node_group" "primary" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "primary"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["m5.xlarge"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ── Addons ───────────────────────────────────────────────────────────────────
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.node.arn
  depends_on               = [aws_eks_node_group.primary]
}

# EKS ships gp2 as default. gp3 is cheaper and faster; name it explicitly so the
# common module's storage_class variable has something to point at.
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = var.storage_class
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  # WaitForFirstConsumer, so a volume is created in the AZ the pod lands in.
  # Immediate binding on a multi-AZ cluster can place the disk where the pod
  # cannot reach it.
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type = "gp3"
  }
  depends_on = [aws_eks_addon.ebs_csi]
}

output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_ca" { value = aws_eks_cluster.this.certificate_authority[0].data }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.oidc.arn }
output "oidc_provider_url" { value = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "") }
