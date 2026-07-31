# dev only. In cloud mode the image ships realm-export-cloud.json, which builds
# its own origins from PUBLIC_BASE_DOMAIN and enables direct access grants — the
# two things this template existed to patch. Mounting it there would be inert
# anyway (cloud reads a different filename), but leaving it would suggest the
# realm is still managed from here, and it is not.
resource "kubernetes_config_map" "realm_export" {
  count = var.mockten_mode == "cloud" ? 0 : 1
  metadata {
    name      = "uam-realm-export"
    namespace = "default"
  }
  data = {
    # templatefile renders redirect_uris/web_origins; the bare GOOGLE_CLIENT_ID
    # placeholders are not ${...} so they pass through for the uam entrypoint to
    # substitute at container start-up.
    "realm-export-dev.json" = templatefile("${path.module}/realm-export.template.json", {
      redirect_uris = var.redirect_uris
      web_origins   = var.web_origins
    })
  }
}

resource "kubernetes_secret" "uam_oauth" {
  metadata {
    name = "uam-oauth-secret"
  }
  data = {
    GOOGLE_CLIENT_ID       = var.google_client_id
    GOOGLE_CLIENT_SECRET   = var.google_client_secret
    FACEBOOK_CLIENT_ID     = var.facebook_client_id
    FACEBOOK_CLIENT_SECRET = var.facebook_client_secret
  }
}

resource "kubernetes_deployment" "uam" {
  # The container exits 1 rather than import a realm whose origins would reject
  # every login. Catch it here instead, so the failure is a plan error naming the
  # variable rather than a CrashLoopBackOff to be diagnosed from logs.
  lifecycle {
    precondition {
      condition     = var.mockten_mode != "cloud" || var.public_base_domain != ""
      error_message = "public_base_domain is required when mockten_mode is cloud."
    }
  }

  metadata {
    name      = "uam-deploy"
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
          # The image's entrypoint starts Keycloak with `--http-port=80`. A non-root
          # process can bind 80 on GKE's COS nodes (ip_unprivileged_port_start=0) but
          # NOT on AKS/EKS Ubuntu nodes (default 1024), where it crash-loops with
          # "Port already bound: 80: Permission denied". NET_BIND_SERVICE does not
          # help — capabilities are not ambient for a non-root process. Running as
          # root binds the privileged port on any node OS, so it is the portable,
          # deliberate choice here (rather than relying on GKE COS's lowered
          # unprivileged-port start). Keycloak is fine as root; this keeps the image
          # unchanged across GKE / AKS / local.
          security_context {
            run_as_user = 0
          }
          env {
            name  = "KC_HOSTNAME"
            value = var.kc_hostname
          }
          env {
            name  = "DEV_MODE"
            value = var.kc_dev_mode
          }
          # cloud only — see the note in ecfront: local k8s is tested with these
          # absent, not set to "dev".
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
          # Both spellings of the bootstrap-admin credentials, on purpose.
          # Keycloak 26 renamed KEYCLOAK_ADMIN/_PASSWORD to
          # KC_BOOTSTRAP_ADMIN_USERNAME/_PASSWORD, and the image now pins 26.7.0.
          # If only the retired name is honoured, NO admin is created on a fresh
          # DB and the e2e-admin bootstrap Job cannot authenticate to the Admin
          # API — a failure that surfaces far from its cause. Whichever name this
          # version ignores costs nothing, so send both rather than guess.
          #
          # The Dockerfile's admin/admin is only a default; these override it.
          env {
            name  = "KEYCLOAK_ADMIN"
            value = var.kc_admin_user
          }
          env {
            name  = "KEYCLOAK_ADMIN_PASSWORD"
            value = var.kc_admin_password
          }
          env {
            name  = "KC_BOOTSTRAP_ADMIN_USERNAME"
            value = var.kc_admin_user
          }
          env {
            name  = "KC_BOOTSTRAP_ADMIN_PASSWORD"
            value = var.kc_admin_password
          }
          env_from {
            secret_ref {
              name     = kubernetes_secret.uam_oauth.metadata[0].name
              optional = true
            }
          }
          dynamic "volume_mount" {
            for_each = var.mockten_mode == "cloud" ? [] : [1]
            content {
              name       = "realm-export"
              mount_path = "/opt/keycloak/staging/realm-export-dev.json"
              sub_path   = "realm-export-dev.json"
            }
          }
        }
        dynamic "volume" {
          for_each = var.mockten_mode == "cloud" ? [] : [1]
          content {
            name = "realm-export"
            config_map {
              name = kubernetes_config_map.realm_export[0].metadata[0].name
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
      port        = 80
      target_port = 80
    }
  }
}
