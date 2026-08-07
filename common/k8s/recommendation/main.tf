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
          image = "ghcr.io/mockten/recommendation:${var.image_tag}"
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

# Hourly retrain. The recommendation model is otherwise only trained on deploy (the
# behavior seeder) and by the service's startup self-heal — so once a cluster is up,
# the LightFM model that /recommend actually serves (lightfm_model.pkl) never picks
# up newly-placed orders until the next deploy. This CronJob POSTs /train every hour;
# train_model_logic re-reads the live Transaction/Geo tables and re-saves the model
# (and metrics.json), which the service's poll loop then hot-reloads. It hits the
# service directly over cluster DNS (no apigw dependency) and the service's own
# in-progress guard makes a redundant trigger a no-op.
#
# NOTE: this drives the SERVED model (LightFM via the service). The Airflow DAG
# writes a separate svd_model.pkl the service does not read, so scheduling the DAG
# would not change what /recommend returns — hence the CronJob, not a DAG schedule.
resource "kubernetes_cron_job_v1" "recommendation_retrain" {
  metadata {
    name      = "recommendation-retrain"
    namespace = "default"
  }
  spec {
    schedule                      = "0 * * * *" # top of every hour
    concurrency_policy            = "Forbid"    # never overlap runs
    starting_deadline_seconds     = 120
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 1
    job_template {
      metadata {}
      spec {
        backoff_limit = 2
        # Auto-clean finished Jobs so hourly runs don't pile up as Exited entries
        # in the Container List (same rationale as the behavior seeder).
        ttl_seconds_after_finished = 120
        template {
          metadata {
            labels = { app = "recommendation-retrain" }
          }
          spec {
            restart_policy = "Never"
            container {
              name  = "trigger"
              image = "busybox:1.36"
              command = [
                "sh", "-c",
                "wget -q -O- --post-data='{}' --header='Content-Type: application/json' http://recommendation-service.default.svc.cluster.local:8080/train && echo ' — retrain triggered'"
              ]
            }
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
