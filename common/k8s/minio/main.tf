resource "kubernetes_persistent_volume_claim" "minio_data" {
  metadata {
    name      = "minio-data-pvc"
    namespace = "default"
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
  # GKE's standard-rwo is WaitForFirstConsumer: the PV isn't provisioned until a
  # pod mounts the PVC. With the default wait_until_bound, terraform would block
  # creating this PVC (waiting for a bind) before it ever creates the minio
  # Deployment that would trigger the bind — a deadlock that times out. Don't
  # wait; the Deployment that follows binds it. Harmless on hostpath (binds
  # immediately anyway).
  wait_until_bound = false
}

resource "kubernetes_deployment" "minio" {
  metadata {
    name      = "minio-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "minio"
      }
    }
    template {
      metadata {
        labels = {
          app = "minio"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        init_container {
          name    = "photos-downloader"
          image   = "alpine:3.19"
          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
              apk add --no-cache curl unzip
              mkdir -p /photos
              RELEASE_BASE="https://github.com/mockten/mockten/releases/download/photos-v1"
              for part in photos_part1.zip photos_part2.zip; do
                echo "Downloading $part ..."
                curl -L --fail --retry 3 "$RELEASE_BASE/$part" -o "/tmp/$part"
                echo "Extracting $part ..."
                unzip -o "/tmp/$part" -d /photos/
                rm "/tmp/$part"
              done
              echo "Photos download complete."
            EOT
          ]
          volume_mount {
            name       = "photos"
            mount_path = "/photos"
          }
        }
        container {
          name  = "minio"
          image = "ghcr.io/mockten/minio:latest"
          port {
            container_port = 9000
          }
          volume_mount {
            name       = "minio-data"
            mount_path = "/data"
          }
          volume_mount {
            name       = "photos"
            mount_path = "/photos"
            read_only  = true
          }
        }
        volume {
          name = "minio-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.minio_data.metadata[0].name
          }
        }
        volume {
          name = "photos"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "minio" {
  metadata {
    name      = "minio-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "minio"
    }
    port {
      name        = "http"
      port        = 9000
      target_port = 9000
    }
  }
}
