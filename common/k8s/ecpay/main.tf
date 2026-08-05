resource "kubernetes_secret" "stripe" {
  metadata {
    name      = "stripe-secret"
    namespace = "default"
  }
  data = {
    # env_from projects each key as an env var name verbatim, and ecpay reads
    # `SecretKeyString` (api.go), which is what docker-compose sets it to. Naming
    # this key STRIPE_SECRET_KEY meant ecpay never saw the key at all.
    SecretKeyString = var.stripe_secret_key
  }
}

resource "kubernetes_deployment" "ecpay" {
  metadata {
    name      = "ecpay-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "ecpay"
      }
    }
    template {
      metadata {
        labels = {
          app = "ecpay"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "ecpay"
          image = "ghcr.io/mockten/ecpay:${var.image_tag}"
          env_from {
            secret_ref {
              name = kubernetes_secret.stripe.metadata[0].name
            }
          }
          env {
            name  = "MysqlUser"
            value = "mocktenusr"
          }
          env {
            name  = "MysqlPassword"
            value = "mocktenpassword"
          }
          env {
            name  = "DbHost"
            value = "mysql-service.default.svc.cluster.local:3306"
          }
          env {
            name  = "MysqlDB"
            value = "mocktendb"
          }
          env {
            name  = "RANKING_SERVICE_URL"
            value = "http://ranking-service.default.svc.cluster.local:8080"
          }
          env {
            name  = "GOGC"
            value = "50"
          }
          env {
            name  = "GOMEMLIMIT"
            value = "30MiB"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ecpay" {
  metadata {
    name      = "ecpay-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "ecpay"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}
