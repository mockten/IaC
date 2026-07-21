resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "redis"
      }
    }
    template {
      metadata {
        labels = {
          app = "redis"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "redis"
          image = "ghcr.io/mockten/redis:latest"
          port {
            container_port = 6379
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "redis"
    }
    port {
      name        = "redis"
      port        = 6379
      target_port = 6379
    }
  }
}
