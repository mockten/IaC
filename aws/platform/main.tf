# ingress-nginx + cert-manager, the counterpart to gcp/platform.
# Kept deliberately parallel: only the load balancer annotations and the DNS-01
# solver differ between clouds.

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
  }
}

variable "region" { type = string }
variable "allowlist_cidr" { type = string }
variable "letsencrypt_email" { type = string }
variable "acme_staging" { type = bool }
variable "route53_zone_id" { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }
variable "host_store" { type = string }
variable "host_sales" { type = string }
variable "host_admin" { type = string }
variable "host_dashboard" { type = string }

# ── ingress-nginx behind a Network Load Balancer ─────────────────────────────
# NLB rather than the default Classic LB: it preserves the client IP, which is
# what makes loadBalancerSourceRanges a real network-level restriction instead
# of an application-level 403.
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [yamlencode({
    controller = {
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
        }
        loadBalancerSourceRanges = [var.allowlist_cidr]
        externalTrafficPolicy    = "Local"
      }
    }
  })]
}

data "kubernetes_service" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.ingress_nginx]
}

# ── cert-manager, with IRSA so the DNS-01 solver can write to Route53 ────────
data "aws_iam_policy_document" "certmgr_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:cert-manager:cert-manager"]
    }
  }
}

resource "aws_iam_role" "certmgr" {
  name               = "mockten-cert-manager-dns01"
  assume_role_policy = data.aws_iam_policy_document.certmgr_assume.json
}

# Narrowest set that still lets ACME write and clean up _acme-challenge TXT.
resource "aws_iam_role_policy" "certmgr" {
  name = "route53-dns01"
  role = aws_iam_role.certmgr.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:GetChange"]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZonesByName"]
        Resource = "*"
      },
    ]
  })
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.16.2"
  namespace        = "cert-manager"
  create_namespace = true

  values = [yamlencode({
    crds = { enabled = true }
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.certmgr.arn
      }
    }
    # By default cert-manager self-checks DNS-01 against the domain's
    # authoritative nameservers. For a delegated subdomain the parent's servers
    # can answer SERVFAIL or time out from inside the cluster, so the challenge
    # never completes even though the TXT record is published correctly. This
    # cost hours on GCP; check via public resolvers instead.
    extraArgs = [
      "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
      "--dns01-recursive-nameservers-only",
    ]
  })]
}

resource "kubectl_manifest" "cluster_issuer" {
  depends_on = [helm_release.cert_manager]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt" }
    spec = {
      acme = {
        # Production allows 5 certificates per exact identifier set per 168h.
        # A stack that rebuilds whole exhausts that in five rebuilds, and every
        # Order then fails with 429 — which looks like a DNS fault but is not.
        server = var.acme_staging ? (
          "https://acme-staging-v02.api.letsencrypt.org/directory"
          ) : (
          "https://acme-v02.api.letsencrypt.org/directory"
        )
        email = var.letsencrypt_email
        # An account registered against staging is invalid against production,
        # so the key must differ per environment.
        privateKeySecretRef = {
          name = var.acme_staging ? "letsencrypt-account-key-staging" : "letsencrypt-account-key"
        }
        solvers = [{
          dns01 = {
            route53 = {
              region       = var.region
              hostedZoneID = var.route53_zone_id
            }
          }
        }]
      }
    }
  })
}

output "ingress_hostname" {
  value = data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname
}
