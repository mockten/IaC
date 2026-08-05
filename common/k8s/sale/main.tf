resource "kubernetes_deployment" "sale" {
  metadata {
    name      = "sale-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "sale"
      }
    }
    template {
      metadata {
        labels = {
          app = "sale"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "sale"
          image = "ghcr.io/mockten/sale:${var.image_tag}"
          env {
            name  = "MYSQL_DSN"
            value = "mocktenusr:mocktenpassword@tcp(mysql-service.default.svc.cluster.local:3306)/mocktendb?parseTime=true"
          }
          env {
            name  = "MEILI_SVC"
            value = "meilisearch-service.default.svc.cluster.local"
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

resource "kubernetes_service" "sale" {
  metadata {
    name      = "sale-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "sale"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}
