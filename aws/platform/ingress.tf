# Host-based HTTPS Ingress — identical routing to gcp/platform/ingress.tf.
# Any change here almost certainly belongs there too.

locals {
  ecfront_paths = [
    { path = "/api/test/", svc = "backdoor-service", port = 8080 },
    { path = "/api/", svc = "apigw-service", port = 80 },
    { path = "/realms/mockten-realm-dev/broker/", svc = "uam-service", port = 80 },
    { path = "/realms/mockten-realm-dev/login-actions/", svc = "uam-service", port = 80 },
    # Keycloak's own CSS/JS. Without this they fall through to "/" and the
    # storefront SPA answers 200 with index.html for every stylesheet request,
    # so the login pages render unstyled. The 200 makes it look like the asset
    # loaded, which is why this hid for a long time on GCP.
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

# Served at the ROOT of its own host — no /dashboard prefix, no rewrite.
# In cloud mode the dashboard owns the host and calls /api/... directly; keeping
# the dev prefix here made every API request 404.
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
