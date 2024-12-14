resource "kubernetes_deployment" "ecfront" {
  metadata {
    name = "ecfront-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "ecfront"
      }
    }
    template {
      metadata {
        labels = {
          app = "ecfront"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "ecfront"
          image = "ghcr.io/mockten/ecfront:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "ecfront" {
  metadata {
    name      = "ecfront-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "ecfront"
    }
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
  }
}
