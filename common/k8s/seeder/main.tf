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
    # Auto-delete the finished Job (and its pod) 5 minutes after it completes, so
    # one-shot Jobs never linger as "Exited/Succeeded" entries in the Container List
    # (long-running Deployments stay visible so failures are still noticed). Long
    # enough to read its logs first. Note: because Terraform then sees the Job gone,
    # the next `apply` recreates it — i.e. every deploy re-seeds and re-triggers
    # training, which keeps the model fresh on each rollout.
    ttl_seconds_after_finished = 300
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

        # The seeder seeds the orders and then POSTs the recommendation /train API.
        # That POST otherwise races the recommendation service's startup: if it lands
        # before the service is Ready it is lost, the seeder Job still succeeds, and
        # the model is never trained — the dashboard then reads Environment PENDING on
        # an otherwise-healthy stack. Block until the training target is actually
        # reachable so the trigger always lands. (Cloud-agnostic — every root shares
        # this module.)
        init_container {
          name    = "wait-for-recommendation"
          image   = "busybox:1.36"
          command = ["sh", "-c", "until wget -q -T 3 -O /dev/null http://recommendation-service.default.svc.cluster.local:8080/health 2>/dev/null; do echo 'waiting for recommendation to be ready...'; sleep 5; done; sleep 10; echo 'recommendation ready'"]
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
