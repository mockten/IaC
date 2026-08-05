resource "kubernetes_deployment" "product" {
  metadata {
    name      = "product-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "product"
      }
    }
    template {
      metadata {
        labels = {
          app = "product"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "product"
          image = "ghcr.io/mockten/product:${var.image_tag}"
          port {
            container_port = 50051
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "product" {
  metadata {
    name      = "product-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "product"
    }
    port {
      name        = "http"
      port        = 50052
      target_port = 50052
    }
  }
}