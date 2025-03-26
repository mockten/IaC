resource "kubernetes_deployment" "minio" {
  metadata {
    name = "minio-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "minio"
      }
    }
    template {
      metadata {
        labels = {
          app = "minio"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "minio"
          image = "ghcr.io/mockten/minio:latest"
          port {
            container_port = 9000
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "minio" {
  metadata {
    name      = "minio-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "minio"
    }
    port {
      name        = "http"
      port        = 9000
      target_port = 9000
    }
  }
}
