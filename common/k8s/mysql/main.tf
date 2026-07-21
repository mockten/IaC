resource "kubernetes_secret" "mysql" {
  metadata {
    name      = "mysql-secret"
    namespace = "default"
  }
  data = {
    MYSQL_ROOT_PASSWORD = "rootpassword"
    MYSQL_PASSWORD      = "mocktenpassword"
  }
}

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

          env_from {
            secret_ref {
              name = kubernetes_secret.mysql.metadata[0].name
            }
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "mocktendb"
          }
          env {
            name  = "MYSQL_USER"
            value = "mocktenusr"
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
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class
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