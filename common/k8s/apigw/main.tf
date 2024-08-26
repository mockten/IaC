resource "kubernetes_deployment" "apigw" {
  metadata {
    name = "apigw-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "apigw"
      }
    }
    template {
      metadata {
        labels = {
          app = "apigw"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "apigw"
          image = "ghcr.io/mockten/mockten/apigw:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "apigw" {
  metadata {
    name      = "apigw-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "apigw"
    }
    port {
      name        = "http"
      port        = 80
      target_port = 8082
    }
  }
}