locals {
  config_json = jsondecode(file("${path.module}/config.json"))
  realm_json  = templatefile("${path.module}/realm-export.template.json", local.config_json)
}

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
          image = "ghcr.io/mockten/uam:latest"
          port {
            container_port = 80
          }
          env {
            name  = "KC_HOSTNAME"
            value = "localhost"
          }
          volume_mount {
            name       = "realm-config"
            mount_path = "/opt/keycloak/data/import/realm-export.json"
            sub_path   = "realm-export.json"
            read_only  = true
          }
        }
        volume {
          name = "realm-config"
          config_map {
            name = kubernetes_config_map.uam_realm.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_config_map" "uam_realm" {
  metadata {
    name      = "uam-realm-config"
    namespace = "default"
  }
  data = {
    "realm-export.json" = local.realm_json
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
      port        = 80
      target_port = 80
    }
  }
}