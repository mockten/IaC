# GCP cloud-native ingress data plane — the counterpart to aws/platform (ALB via
# the AWS Load Balancer Controller) and azure/appgw (App Gateway via AGIC). Unlike
# the old gcp/ (ingress-nginx + cert-manager), this uses Google's OWN load balancer:
# the GKE Ingress (gce) controller provisions an external Application Load Balancer,
# TLS is a Google-managed certificate (no cert-manager, no Let's Encrypt rate
# limit), the CDN is Cloud CDN (a flag on the backend), and the IP allowlist is
# Cloud Armor. The Ingress itself lives in ./ingress.tf.
#
# BackendConfig/FrontendConfig/ManagedCertificate are GKE CRDs, so they are applied
# with kubectl_manifest (no plan-time CRD check, like the old ClusterIssuer was).

# ── Cloud Armor: allow only the operator IP(s) + the cluster egress ──────────
# The counterpart to aws/'s WAF IP set and azure/'s NSG. default_rule denies; the
# allow rule admits ALLOWLIST_CIDR plus the cluster's Cloud NAT egress /32 (so the
# dashboard's in-cluster self-probe of the public HTTPS URL is not blocked — the
# same reason aws/ allowlists its NAT IP and azure/ its AKS egress IP).
resource "google_compute_security_policy" "allow" {
  name    = "mockten-allow"
  project = var.project

  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = concat(
          [for c in split(",", var.allowlist_cidr) : trimspace(c)],
          [var.egress_cidr],
        )
      }
    }
    description = "Allow the operator allowlist and the cluster egress IP."
  }

  rule {
    action   = "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    description = "Default deny."
  }
}

# ── TLS: one Google-managed certificate covering all four hosts ──────────────
# Google provisions and auto-renews it once the hosts resolve to the LB IP. No
# cert-manager, and no Let's Encrypt 5-per-week limit — the exact trap that broke
# rebuilds on 2026-07-20 (see the old platform/main.tf) simply does not exist here.
# First issuance waits on DNS + LB propagation (~10-30 min) but is never rate-limited.
resource "kubectl_manifest" "managed_cert" {
  yaml_body = yamlencode({
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "mockten-cert"
      namespace = "default"
    }
    spec = {
      domains = [var.host_store, var.host_sales, var.host_admin, var.host_dashboard]
    }
  })
}

# ── FrontendConfig: redirect HTTP→HTTPS at the LB ────────────────────────────
resource "kubectl_manifest" "frontend_config" {
  yaml_body = yamlencode({
    apiVersion = "networking.gke.io/v1beta1"
    kind       = "FrontendConfig"
    metadata = {
      name      = "mockten-fe"
      namespace = "default"
    }
    spec = {
      redirectToHttps = { enabled = true }
    }
  })
}

# ── BackendConfig per backend service: Cloud CDN + Cloud Armor + health check ─
# GKE creates one LB backend service per k8s Service referenced by the Ingress, and
# attaches the BackendConfig named by the Service's cloud.google.com/backend-config
# annotation (patched on below). Each backend gets the Cloud Armor policy and — for
# the cacheable storefront — Cloud CDN.
#
# HEALTH CHECK: unlike aws/ (ALB success-codes = 200-499) and azure/ (App Gateway
# health-probe-status-codes = 200-499), a GKE health check only treats HTTP 200 as
# healthy — there is no success-code range. So each backend must be probed on a path
# that returns 200, or its LB backend goes UNHEALTHY and that route 502s. The paths
# below are the first-deploy tuning point: verify each against the running service
# (kubectl exec ... curl) and adjust. `/` is correct only for services that 200 there.
locals {
  # name -> { k8s service, serving port, health path (must return 200), enable CDN }
  backends = {
    ecfront   = { service = "ecfront-service", port = 80, health = "/", cdn = true }
    apigw     = { service = "apigw-service", port = 80, health = "/", cdn = false }
    uam       = { service = "uam-service", port = 80, health = "/realms/mockten-realm-dev/", cdn = false }
    backdoor  = { service = "backdoor-service", port = 8080, health = "/", cdn = false }
    dashboard = { service = "dashboard-service", port = 3001, health = "/", cdn = false }
  }
}

resource "kubectl_manifest" "backend_config" {
  for_each = local.backends

  yaml_body = yamlencode({
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "bc-${each.key}"
      namespace = "default"
    }
    spec = {
      securityPolicy = { name = google_compute_security_policy.allow.name }
      cdn            = { enabled = each.value.cdn }
      healthCheck = {
        type        = "HTTP"
        port        = each.value.port
        requestPath = each.value.health
      }
    }
  })
}

# Attach each BackendConfig to its Service without editing the shared common/k8s
# module: patch the annotations onto the existing Services. cloud.google.com/neg
# opts the ClusterIP Service into container-native (NEG) load balancing, which the
# gce Ingress needs on a VPC-native cluster.
resource "kubernetes_annotations" "backend" {
  for_each = local.backends

  api_version = "v1"
  kind        = "Service"
  metadata {
    name      = each.value.service
    namespace = "default"
  }
  annotations = {
    "cloud.google.com/backend-config" = jsonencode({ default = "bc-${each.key}" })
    "cloud.google.com/neg"            = jsonencode({ ingress = true })
  }
  force = true

  depends_on = [kubectl_manifest.backend_config]
}
