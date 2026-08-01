locals {
  agic_annotations = {
    "kubernetes.io/ingress.class" = "azure/application-gateway"
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
