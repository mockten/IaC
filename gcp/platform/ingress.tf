# Host-based HTTPS Ingress. cert-manager auto-issues a cert per host from the tls
# block + the cluster-issuer annotation. The three ecfront hosts share backend
# routing (mirrors local's ecfront-ingress); sales/admin add a root redirect so
# the subdomain lands on that portal without any app change.

locals {
  # Longest-prefix wins in nginx, so order is cosmetic; all Prefix for safety.
  ecfront_paths = [
    { path = "/api/test/", svc = "backdoor-service", port = 8080 },
    { path = "/api/", svc = "apigw-service", port = 80 },
    { path = "/realms/mockten-realm-dev/broker/", svc = "uam-service", port = 80 },
    { path = "/realms/mockten-realm-dev/login-actions/", svc = "uam-service", port = 80 },
    # Keycloak's own CSS/JS/images. Without this they fall through to "/" and the
    # storefront SPA answers 200 with index.html for every stylesheet request —
    # so the login and account-linking pages render as unstyled HTML with a
    # giant broken SVG. The 200 makes it look like the asset loaded, which is
    # why this hid for so long.
    { path = "/resources/", svc = "uam-service", port = 80 },
    { path = "/", svc = "ecfront-service", port = 80 },
  ]

  ecfront_hosts = {
    store = { host = var.host_store, app_root = null }
    sales = { host = var.host_sales, app_root = "/seller/login" }
    admin = { host = var.host_admin, app_root = "/admin" }
  }
}

resource "kubernetes_ingress_v1" "ecfront" {
  for_each = local.ecfront_hosts

  metadata {
    name      = "ecfront-${each.key}"
    namespace = "default"
    annotations = merge(
      { "cert-manager.io/cluster-issuer" = "letsencrypt" },
      each.value.app_root == null ? {} : { "nginx.ingress.kubernetes.io/app-root" = each.value.app_root }
    )
  }

  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = [each.value.host]
      secret_name = "${each.key}-tls"
    }
    rule {
      host = each.value.host
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

  depends_on = [helm_release.ingress_nginx, kubectl_manifest.cluster_issuer]
}

# The dashboard is reachable ONLY at dashboard.<domain> — deliberately not at
# <storefront>/dashboard. In cloud the deployment is internet-facing, so the
# domains are kept genuinely separate rather than being aliases of each other.
# (Local keeps <base>/dashboard; that difference is intentional.)
#
# Consequence: the E2E's dashboard specs target <base>/dashboard and will fail
# against cloud until the suite points at the dashboard host in cloud mode —
# tracked in MOCKTEN_REQUESTS.md.
#
# Served at the ROOT of its own host — no /dashboard prefix, no rewrite.
#
# This used to carry app-root=/dashboard/ + a rewrite, because the dashboard's JS
# asked for absolute /dashboard/api/... paths. In cloud mode it no longer does:
# the dashboard owns the host and calls /api/... directly, so the old prefix made
# every API request 404 (proved: /api/containers returned 404, not the 401 the
# auth guard should have produced). Only dev still has the /dashboard prefix,
# where a proxy strips it.
resource "kubernetes_ingress_v1" "dashboard" {
  metadata {
    name      = "dashboard"
    namespace = "default"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt"
    }
  }

  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = [var.host_dashboard]
      secret_name = "dashboard-tls"
    }
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

  depends_on = [helm_release.ingress_nginx, kubectl_manifest.cluster_issuer]
}
