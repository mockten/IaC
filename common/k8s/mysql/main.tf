resource "kubernetes_stateful_set" "mysql" {
  metadata {
    name      = "mysql-sts"
    namespace = "default"
  }

  spec {
    service_name = "mysql"
    replicas     = 1

    selector {
      match_labels = {
        app = "mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        image_pull_secrets {
          name = var.secret_name
        }

        container {
          name  = "mysql"
          image = "ghcr.io/mockten/mysql:latest"

          port {
            container_port = 3306
          }

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "rootpassword"
          }
          env {
            name  = "MYSQL_DATABASE"
            value = "mocktendb"
          }
          env {
            name  = "MYSQL_USER"
            value = "mocktenusr"
          }
          env {
            name  = "MYSQL_PASSWORD"
            value = "mocktenpassword"
          }

          volume_mount {
            name       = "mysql-storage"
            mount_path = "/var/lib/mysql"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "mysql-storage"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "5Gi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mysql" {
  metadata {
    name      = "mysql-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "mysql"
    }
    port {
      name        = "mysql"
      port        = 3306
      target_port = 3306
    }
  }
}