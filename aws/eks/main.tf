# EKS cluster + managed node group, the counterpart to gcp/gke and azure/aks.
#
# Two AWS-specific things have no GCP equivalent and are easy to miss:
#
#   1. IRSA. GKE has Workload Identity built in; on EKS you must create an OIDC
#      provider from the cluster and bind IAM roles to service accounts through
#      it. cert-manager's DNS-01 solver needs this to touch Route53.
#   2. The EBS CSI driver is NOT installed by default on recent EKS versions.
#      Without it every PVC stays Pending forever with no obvious cause — the
#      same class of failure as the minio WaitForFirstConsumer deadlock on GKE.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

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
    public_access_cidrs     = concat([for c in split(",", var.allowlist_cidr) : trimspace(c)], var.master_authorized_extra)
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
    # Lets the EBS CSI driver create volumes for PVCs. This one is a service-role
    # managed policy, so its ARN carries the "service-role/" path — without it the
    # attach fails with NoSuchEntity.
    "service-role/AmazonEBSCSIDriverPolicy",
  ])
  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

# 2 x m7i-flex.large (2 vCPU / 8 GiB each = 4 vCPU / 16 GiB) ≈ the 2 x D2s_v7 that
# work on AKS and the 2 x e2-standard-4 on GKE. m7i-flex.large is chosen over a
# plain m5.xlarge for one hard reason: a new AWS Free-tier ("Free plan") account
# blocks non-free-tier-eligible instance types outright ("InvalidParameter
# Combination: not eligible for Free Tier"), and the flex .large types ARE on the
# eligible list. The whole stack is ~21 pods, so per-node ENI pod slots matter as
# much as CPU/RAM — two .large nodes give enough of both.
resource "aws_eks_node_group" "primary" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "primary"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["m7i-flex.large"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ── Addons ───────────────────────────────────────────────────────────────────
# The EBS CSI controller needs its OWN IRSA role. It cannot use the node instance
# profile: EKS managed nodes launch with an IMDS hop limit of 1, so a pod's call
# to 169.254.169.254 times out ("no EC2 IMDS role found") and the addon hangs in
# CREATING until timeout. IRSA (a projected web-identity token) sidesteps IMDS
# entirely. The trust must target the addon's SA, kube-system:ebs-csi-controller-sa.
locals {
  oidc_url = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn
  depends_on               = [aws_eks_node_group.primary, aws_iam_role_policy_attachment.ebs_csi]
}

# The gp3 StorageClass that pairs with this addon is a kubernetes-provider
# resource, so it lives at the root (main.tf), not here: the kubernetes provider
# is configured from this module's outputs, and a provider-consuming resource
# inside the same module would form a cycle. This module stays pure-AWS.
