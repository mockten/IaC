locals {
  geocoding_config = jsonencode({
    nominatim_url = "https://nominatim.openstreetmap.org/search"
    user_agent    = "mockten/1.0 (mockten@mockten.com)"
    country_mapping = {
      jp = "Japan"
      sg = "Singapore"
      us = "United States"
      fr = "France"
      br = "Brazil"
    }
    mysql = {
      host   = "mysql-service.default.svc.cluster.local"
      user   = "mocktenusr"
      pass   = "mocktenpassword"
      db     = "mocktendb"
      params = "parseTime=true&charset=utf8mb4&collation=utf8mb4_unicode_ci"
    }
  })
}

resource "kubernetes_config_map" "geocoding_config" {
  metadata {
    name      = "geocoding-config"
    namespace = "default"
  }
  data = {
    "config.json" = local.geocoding_config
  }
}

resource "kubernetes_deployment" "geocoding" {
  metadata {
    name      = "geocoding-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "geocoding"
      }
    }
    template {
      metadata {
        labels = {
          app = "geocoding"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "geocoding"
          image = "ghcr.io/mockten/geocoding:${var.image_tag}"
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
          volume_mount {
            name       = "geocoding-config"
            mount_path = "/app/config.json"
            sub_path   = "config.json"
            read_only  = true
          }
        }
        volume {
          name = "geocoding-config"
          config_map {
            name = kubernetes_config_map.geocoding_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "geocoding" {
  metadata {
    name      = "geocoding-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "geocoding"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}
