# Host-based Ingress on the GKE (gce) controller → external Application LB. TLS is
# the Google-managed certificate (../platform: kubectl_manifest.managed_cert), the
# HTTP→HTTPS redirect and the Cloud Armor/CDN come from the Frontend/BackendConfigs,
# so there is no per-host `tls` block or cert-manager annotation here (that is the
# old nginx model). The gce controller picks the reserved global static IP by name.
#
# NOTE: unlike the nginx version there is no `app-root` redirect for sales/admin —
# GKE Ingress has no equivalent (same trade-off as azure/). The subdomain lands on
# the storefront root; the portal path is reached by the app's own navigation.

locals {
  ecfront_paths = [
    { path = "/api/test/", svc = "backdoor-service", port = 8080 },
    { path = "/api/", svc = "apigw-service", port = 80 },
    { path = "/realms/mockten-realm-dev/broker/", svc = "uam-service", port = 80 },
    { path = "/realms/mockten-realm-dev/login-actions/", svc = "uam-service", port = 80 },
    { path = "/resources/", svc = "uam-service", port = 80 },
    { path = "/", svc = "ecfront-service", port = 80 },
  ]

  ecfront_hosts = {
    store = var.host_store
    sales = var.host_sales
    admin = var.host_admin
  }

  ingress_annotations = {
    "kubernetes.io/ingress.class"                 = "gce"
    "kubernetes.io/ingress.global-static-ip-name" = var.global_ip_name
    "networking.gke.io/managed-certificates"      = "mockten-cert"
    "networking.gke.io/v1beta1.FrontendConfig"    = "mockten-fe"
  }
}

resource "kubernetes_ingress_v1" "ecfront" {
  for_each = local.ecfront_hosts

  metadata {
    name        = "ecfront-${each.key}"
    namespace   = "default"
    annotations = local.ingress_annotations
  }

  spec {
    rule {
      host = each.value
      http {
        dynamic "path" {
          for_each = local.ecfront_paths
          content {
            path      = path.value.path
            path_type = "Prefix"
            backend {
              service {
                name = path.value.svc
                port { number = path.value.port }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubectl_manifest.managed_cert,
    kubectl_manifest.frontend_config,
    kubernetes_annotations.backend,
  ]
}

# The dashboard is reachable ONLY at dashboard.<domain> (see the long note kept in
# git history) — served at the root of its own host.
resource "kubernetes_ingress_v1" "dashboard" {
  metadata {
    name        = "dashboard"
    namespace   = "default"
    annotations = local.ingress_annotations
  }

  spec {
    rule {
      host = var.host_dashboard
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "dashboard-service"
              port { number = 3001 }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubectl_manifest.managed_cert,
    kubectl_manifest.frontend_config,
    kubernetes_annotations.backend,
  ]
}
