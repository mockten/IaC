resource "kubernetes_deployment" "sync" {
  metadata {
    name = "sync-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "sync"
      }
    }
    template {
      metadata {
        labels = {
          app = "sync"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "sync"
          image = "ghcr.io/mockten/sync:latest"
        }
      }
    }
  }
}