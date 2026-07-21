resource "kubernetes_deployment" "recommendation" {
  metadata {
    name      = "recommendation-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "recommendation"
      }
    }
    template {
      metadata {
        labels = {
          app = "recommendation"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "recommendation"
          image = "ghcr.io/mockten/recommendation:latest"
          env {
            name  = "MYSQL_HOST"
            value = "mysql-service.default.svc.cluster.local"
          }
          env {
            name  = "MINIO_ENDPOINT"
            value = "minio-service.default.svc.cluster.local:9000"
          }
          env {
            name  = "RANKING_SERVICE_URL"
            value = "http://ranking-service.default.svc.cluster.local:8080"
          }
          env {
            name  = "WEB_CONCURRENCY"
            value = "1"
          }
          env {
            name  = "UVICORN_WORKERS"
            value = "1"
          }
          env {
            name  = "MALLOC_ARENA_MAX"
            value = "2"
          }
          env {
            name  = "PYTHONDONTWRITEBYTECODE"
            value = "1"
          }
          env {
            name  = "PYTHONOPTIMIZE"
            value = "1"
          }
          # Without this the pod reports 1/1 Running while uvicorn's supervisor
          # respawns a worker that dies on import (the lightfm SIGILL did exactly
          # that): healthy-looking, zero logs, nothing listening. /model/status
          # only answers once uvicorn is actually serving, so it distinguishes a
          # slow start from a crash loop.
          readiness_probe {
            http_get {
              path = "/model/status"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "recommendation" {
  metadata {
    name      = "recommendation-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "recommendation"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}
