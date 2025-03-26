resource "kubernetes_deployment" "meilisearch" {
  metadata {
    name = "meilisearch-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "meilisearch"
      }
    }
    template {
      metadata {
        labels = {
          app = "meilisearch"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "meilisearch"
          image = "ghcr.io/mockten/meilisearch:latest"
          port {
            container_port = 7700
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "meilisearch" {
  metadata {
    name      = "meilisearch-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "meilisearch"
    }
    port {
      name        = "http"
      port        = 7700
      target_port = 7700
    }
  }
}
