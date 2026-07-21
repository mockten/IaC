resource "kubernetes_deployment" "shipment" {
  metadata {
    name      = "shipment-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "shipment"
      }
    }
    template {
      metadata {
        labels = {
          app = "shipment"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "shipment"
          image = "ghcr.io/mockten/shipment:latest"
          env {
            name  = "TEST_MODE"
            value = "true"
          }
          env {
            name  = "TICK_INTERVAL_SECONDS"
            value = "200"
          }
          env {
            name  = "MYSQL_DSN"
            value = "mocktenusr:mocktenpassword@tcp(mysql-service.default.svc.cluster.local:3306)/mocktendb?parseTime=true"
          }
          env {
            name  = "GOGC"
            value = "30"
          }
          env {
            name  = "GOMEMLIMIT"
            value = "14MiB"
          }
          env {
            name  = "GOMAXPROCS"
            value = "1"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "shipment" {
  metadata {
    name      = "shipment-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "shipment"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}
