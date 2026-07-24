# One-shot behavior seeder. On a fresh cluster the store has zero purchases, and
# the Airflow recommendation pipeline derives its training set from the Order
# table — so with no orders the model trains on nothing and the storefront shows
# empty recommendations. Locally the Taskfile runs mockten's behavior_seeder.py
# on the host; in the cloud the ingress is IP-allowlisted, so instead we run the
# same seeder as an in-cluster Job that reaches mysql / apigw over service DNS and
# is unaffected by loadBalancerSourceRanges.
#
# Requires the seeder packaged as a one-shot image (var.image); mockten publishes
# it. The Job runs once — re-applying with the same spec leaves the completed Job
# in place and does not re-seed.
resource "kubernetes_job" "seed" {
  metadata {
    name      = "behavior-seeder"
    namespace = "default"
  }

  spec {
    # Auto-delete the finished Job (and its pod) 10 minutes after it completes, so
    # it stops showing up as a permanent "Exited/Succeeded" entry in the Container
    # List. Long enough to read its logs first. Note: because Terraform then sees
    # the Job gone, the next `apply` recreates it — i.e. every deploy re-seeds and
    # re-triggers training, which keeps the model fresh on each rollout.
    ttl_seconds_after_finished = 600
    backoff_limit              = 3
    template {
      metadata {
        labels = { app = "behavior-seeder" }
      }
      spec {
        restart_policy = "Never"

        image_pull_secrets {
          name = "ghcr-secret"
        }

        container {
          name  = "seeder"
          image = var.image

          env {
            name  = "MYSQL_HOST"
            value = "mysql-service.default.svc.cluster.local"
          }
          env {
            name  = "MYSQL_PORT"
            value = "3306"
          }
          env {
            name  = "MYSQL_USER"
            value = "mocktenusr"
          }
          env {
            name  = "MYSQL_PASSWORD"
            value = "mocktenpassword"
          }
          env {
            name  = "MYSQL_DB"
            value = "mocktendb"
          }
          # Ranking + training APIs, reached in-cluster through Kong (apigw) so we
          # bypass the IP-allowlisted public ingress entirely.
          env {
            name  = "RANKING_API"
            value = "http://apigw-service.default.svc.cluster.local/api/ranking/update"
          }
          env {
            name  = "RECOMMENDATION_TRAIN_API"
            value = "http://apigw-service.default.svc.cluster.local/api/recommendation/train"
          }
        }
      }
    }
  }

  wait_for_completion = false
}
