resource "kubernetes_deployment" "ranking" {
  metadata {
    name      = "ranking-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "ranking"
      }
    }
    template {
      metadata {
        labels = {
          app = "ranking"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "ranking"
          image = "ghcr.io/mockten/ranking:latest"
          port {
            container_port = 8080
          }
          env {
            name  = "REDIS_HOST"
            value = "redis-service.default.svc.cluster.local:6379"
          }
          env {
            name  = "MYSQL_DSN"
            value = "mocktenusr:mocktenpassword@tcp(mysql-service.default.svc.cluster.local:3306)/mocktendb?parseTime=true"
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

resource "kubernetes_service" "ranking" {
  metadata {
    name      = "ranking-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "ranking"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}
