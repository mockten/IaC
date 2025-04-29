resource "kubernetes_deployment" "searchitem" {
  metadata {
    name = "searchitem-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "searchitem"
      }
    }
    template {
      metadata {
        labels = {
          app = "searchitem"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "searchitem"
          image = "ghcr.io/mockten/searchitem:latest"
          port {
            container_port = 50051
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "searchitem" {
  metadata {
    name      = "searchitem-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "searchitem"
    }
    port {
      name        = "http"
      port        = 50051
      target_port = 50051
    }
  }
}