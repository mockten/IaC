resource "kubernetes_deployment" "cart" {
  metadata {
    name      = "cart-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "cart"
      }
    }
    template {
      metadata {
        labels = {
          app = "cart"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "cart"
          image = "ghcr.io/mockten/cart:${var.image_tag}"
          port {
            container_port = 50053
          }
          env {
            name  = "GOGC"
            value = "50"
          }
          env {
            name  = "GOMEMLIMIT"
            value = "22MiB"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "cart" {
  metadata {
    name      = "cart-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "cart"
    }
    port {
      name        = "grpc"
      port        = 50053
      target_port = 50053
    }
  }
}
