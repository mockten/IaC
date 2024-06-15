resource "kubernetes_secret" "ghcr" {
  metadata {
    name = "ghcr-secret"
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      "auths" = {
        "https://ghcr.io" = {
          "auth" :  base64encode("${var.github_username}:${var.github_token}")
        }
      }
    })
  }
}
resource "kubernetes_deployment" "ecfront" {
  metadata {
    name = "ecfront-deploy"
    namespace = "default"
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "ecfront"
      }
    }
    template {
      metadata {
        labels = {
          app = "ecfront"
        }
      }
      spec {
        image_pull_secrets {
          name = kubernetes_secret.ghcr.metadata[0].name
        }
        container {
          name  = "ecfront"
          image = "ghcr.io/mockten/mockten/ecfront:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "ecfront" {
  metadata {
    name      = "ecfront-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "ecfront"
    }
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
  }
}