# The image deliberately carries no Stripe key: docker-entrypoint.sh renders
# /config.js from the container's environment at start-up, so the same artifact
# is promotable across environments. The value is publishable (it ships in the
# client bundle to every visitor), but it is still environment-specific, so it
# is supplied here rather than baked in. If it is unset the storefront serves
# and only card payments break.
resource "kubernetes_secret" "ecfront_config" {
  metadata {
    name      = "ecfront-config"
    namespace = "default"
  }
  data = {
    stripe_public_key = var.stripe_public_key
  }
}

resource "kubernetes_deployment" "ecfront" {
  metadata {
    name      = "ecfront-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
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
          name = var.secret_name
        }
        container {
          name  = "ecfront"
          image = "ghcr.io/mockten/ecfront:latest"
          port {
            container_port = 80
          }
          env {
            name = "STRIPE_PUBLIC_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.ecfront_config.metadata[0].name
                key  = "stripe_public_key"
              }
            }
          }
          # Same /config.js mechanism as the Stripe key: the SPA bundle carries no
          # domain, so a clone of this repo never inherits someone else's host.
          #
          # Emitted only in cloud. mockten's hand-off says to leave MOCKTEN_MODE
          # unset for local k8s, so absence — not the string "dev" — is what that
          # path is tested against.
          dynamic "env" {
            for_each = var.mockten_mode == "cloud" ? [1] : []
            content {
              name  = "MOCKTEN_MODE"
              value = var.mockten_mode
            }
          }
          dynamic "env" {
            for_each = var.public_base_domain == "" ? [] : [1]
            content {
              name  = "PUBLIC_BASE_DOMAIN"
              value = var.public_base_domain
            }
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
