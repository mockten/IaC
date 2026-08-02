locals {
  agic_annotations = {
    "kubernetes.io/ingress.class"              = "azure/application-gateway"
    "cert-manager.io/cluster-issuer"           = "letsencrypt"
    "appgw.ingress.kubernetes.io/ssl-redirect" = "true"
    # AGIC derives a per-backend health probe from the Ingress path when a pod has no
    # readinessProbe. Kong (apigw) and Keycloak (uam) return 4xx on those probe paths
    # (e.g. /api/ -> 404), so App Gateway marks the backend Unhealthy and every /api/
    # and login request 502s while the pod is actually fine. Treat any HTTP response
    # as healthy — the same fix aws/routing uses via ALB `success-codes = 200-499`.
    "appgw.ingress.kubernetes.io/health-probe-status-codes" = "200-499"
  }

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
}

resource "kubernetes_ingress_v1" "ecfront" {
  for_each = local.ecfront_hosts

  metadata {
    name        = "ecfront-${each.key}"
    namespace   = "default"
    annotations = local.agic_annotations
  }

  spec {
    tls {
      hosts       = [each.value]
      secret_name = "${each.key}-tls"
    }
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
}

resource "kubernetes_ingress_v1" "dashboard" {
  metadata {
    name        = "dashboard"
    namespace   = "default"
    annotations = local.agic_annotations
  }

  spec {
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
}
