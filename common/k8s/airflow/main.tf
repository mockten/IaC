locals {
  # Both the webserver and the scheduler run the same image and need the same
  # database/broker wiring; only the `airflow <subcommand>` differs. The `airflow`
  # database and the mocktenusr grant are created by the mysql image's init.sql.
  airflow_env = {
    AIRFLOW__CORE__EXECUTOR                     = "LocalExecutor"
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN         = "mysql+mysqldb://mocktenusr:mocktenpassword@mysql-service.default.svc.cluster.local/airflow?charset=utf8mb4"
    AIRFLOW__DATABASE__SQL_ALCHEMY_POOL_SIZE    = "3"
    AIRFLOW__DATABASE__SQL_ALCHEMY_MAX_OVERFLOW = "2"
    AIRFLOW__CORE__FERNET_KEY                   = "j7zLQ3S9kBh2vXpNqWcYeRaFmTuGdIoK8sE4wPlZnJy0="
    AIRFLOW__WEBSERVER__SECRET_KEY              = "mockten-airflow-secret"
    AIRFLOW__CORE__LOAD_EXAMPLES                = "False"
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION  = "False"
    MYSQL_HOST                                  = "mysql-service.default.svc.cluster.local"
    MINIO_ENDPOINT                              = "minio-service.default.svc.cluster.local:9000"
    MALLOC_ARENA_MAX                            = "2"
    PYTHONDONTWRITEBYTECODE                     = "1"
  }

  webserver_env = merge(local.airflow_env, {
    # basic_auth is what the dashboard's Data Pipeline panel authenticates with.
    AIRFLOW__API__AUTH_BACKENDS                   = "airflow.api.auth.backend.basic_auth"
    AIRFLOW__WEBSERVER__EXPOSE_CONFIG             = "True"
    AIRFLOW__WEBSERVER__WORKERS                   = "1"
    AIRFLOW__WEBSERVER__WORKER_TIMEOUT            = "120"
    AIRFLOW__WEBSERVER__WORKER_REFRESH_BATCH_SIZE = "1"
    AIRFLOW__WEBSERVER__WORKER_REFRESH_INTERVAL   = "1800"
  })

  scheduler_env = merge(local.airflow_env, {
    AIRFLOW__SCHEDULER__MAX_DAGRUNS_PER_LOOP_TO_SCHEDULE = "5"
    AIRFLOW__SCHEDULER__PARSING_PROCESSES                = "1"
    AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG               = "1"
  })
}

resource "kubernetes_deployment" "airflow_webserver" {
  metadata {
    name      = "airflow-webserver-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "airflow-webserver"
      }
    }
    template {
      metadata {
        labels = {
          app = "airflow-webserver"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        # The image's /entrypoint.sh runs `airflow db migrate` before exec'ing its
        # argument. Under compose `depends_on` staggers the two services enough to
        # get away with that, but here both pods start at once and race: one wins
        # GET_LOCK('airflow_MIGRATIONS') and blocks on a table metadata lock held
        # by the other's open transaction, and neither side gives up for 30
        # minutes. So migrate exactly once here and skip entrypoint.sh below.
        init_container {
          name  = "airflow-db-init"
          image = "ghcr.io/mockten/airflow:${var.image_tag}"
          command = ["/bin/bash", "-c", <<-EOT
            until airflow db check 2>/dev/null; do
              echo "Waiting for Airflow DB..."
              sleep 2
            done
            airflow db migrate
            airflow users create \
              --username airflow --password airflow \
              --firstname Admin --lastname User \
              --role Admin --email admin@mockten.local 2>/dev/null || true
          EOT
          ]
          dynamic "env" {
            for_each = local.webserver_env
            content {
              name  = env.key
              value = env.value
            }
          }
        }
        container {
          name    = "airflow-webserver"
          image   = "ghcr.io/mockten/airflow:${var.image_tag}"
          command = ["airflow", "webserver"]
          port {
            container_port = 8080
          }
          dynamic "env" {
            for_each = local.webserver_env
            content {
              name  = env.key
              value = env.value
            }
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 20
            period_seconds        = 10
            failure_threshold     = 12
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "airflow_scheduler" {
  metadata {
    name      = "airflow-scheduler-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "airflow-scheduler"
      }
    }
    template {
      metadata {
        labels = {
          app = "airflow-scheduler"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        # The webserver's init container owns the migration; this one only waits
        # for it to finish, so the scheduler never opens a transaction against a
        # half-migrated schema.
        init_container {
          name    = "wait-for-migrations"
          image   = "ghcr.io/mockten/airflow:${var.image_tag}"
          command = ["/bin/bash", "-c", "airflow db check-migrations -t 300"]
          dynamic "env" {
            for_each = local.scheduler_env
            content {
              name  = env.key
              value = env.value
            }
          }
        }
        container {
          name    = "airflow-scheduler"
          image   = "ghcr.io/mockten/airflow:${var.image_tag}"
          command = ["airflow", "scheduler"]
          dynamic "env" {
            for_each = local.scheduler_env
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "airflow_webserver" {
  metadata {
    name      = "airflow-webserver-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "airflow-webserver"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}
