resource "kubernetes_deployment" "uam" {
  metadata {
    name = "uam-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "uam"
      }
    }
    template {
      metadata {
        labels = {
          app = "uam"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "uam"
          image = "ghcr.io/mockten/mockten/uam:latest"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "realm-config"
            mount_path = "/opt/keycloak/data/import"
          }
        }
        volume {
          name = "realm-config"

          config_map {
            name = kubernetes_config_map.mockten_realm.metadata[0].name
            items {
              key  = "realm-export.json"
              path = "realm-export.json"
            }
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "uam" {
  metadata {
    name      = "uam-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "uam"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}