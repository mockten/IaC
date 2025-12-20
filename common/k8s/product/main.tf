resource "kubernetes_deployment" "product" {
  metadata {
    name = "product-deploy"
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
          image = "ghcr.io/mockten/product:latest"
          port {
            container_port = 50052
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