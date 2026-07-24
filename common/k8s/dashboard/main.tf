resource "kubernetes_service_account" "dashboard" {
  metadata {
    name      = "dashboard-sa"
    namespace = "default"
  }
}

resource "kubernetes_role" "dashboard" {
  metadata {
    name      = "dashboard-role"
    namespace = "default"
  }
  # Read pods (Container List / Topology / Log Viewer) and delete them (Restart).
  # Kubernetes has no "restart pod" verb, so Restart deletes the pod and lets the
  # controller recreate it.
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get"]
  }
  # CPU/memory numbers; served by metrics-server (deployed in local/k8s).
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }
  # The namespace's memory budget — the denominator for Total Memory Usage.
  # Namespace-scoped, so still no ClusterRole.
  rule {
    api_groups = [""]
    resources  = ["resourcequotas"]
    verbs      = ["get", "list"]
  }
  # The Container List terminal. Excluded in round 1, then explicitly requested:
  # this is the `kubectl exec -it` equivalent, so it is full shell access to any
  # pod in the namespace for anyone who can reach the dashboard.
  #
  # `get`, NOT `create` — counter-intuitively. Kubernetes derives the RBAC verb
  # from the HTTP method, and the dashboard uses @kubernetes/client-node's Exec,
  # which opens a WebSocket; a WebSocket handshake is always a GET. (`kubectl
  # exec` upgrades a POST instead, which is why it needs `create` — that is the
  # verb everyone reaches for, and it 403s here.) Verified both ways on the
  # cluster: `get` alone works, `create` alone 403s. If the dashboard ever moves
  # to SPDY, add `create`.
  #
  # Note `kubectl auth can-i create pods/exec` wrongly reports "no" even when the
  # rule grants it; use `kubectl auth can-i create pods --subresource=exec`.
  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["get"]
  }
  # Still deliberately no batch/jobs: Sync Trigger and DB export/import remain
  # DEV-only (they go through the Docker socket).
}

resource "kubernetes_role_binding" "dashboard" {
  metadata {
    name      = "dashboard-rb"
    namespace = "default"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.dashboard.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.dashboard.metadata[0].name
    namespace = "default"
  }
}

# Only created when a secret is supplied; otherwise the container generates one
# per start, which is fine except that every restart logs everyone out.
resource "kubernetes_secret" "dashboard_session" {
  count = var.session_secret_enabled ? 1 : 0
  metadata {
    name      = "dashboard-session"
    namespace = "default"
  }
  data = {
    session_secret = var.session_secret
  }
}

resource "kubernetes_deployment" "dashboard" {
  metadata {
    name      = "dashboard-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "dashboard"
      }
    }
    template {
      metadata {
        labels = {
          app = "dashboard"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.dashboard.metadata[0].name

        # Point the public hostnames at the in-cluster ingress ClusterIP. The
        # readiness check fetches https://<domain>/ to prove TLS works; from a pod
        # that hairpins to the external LB IP and times out (so "Environment" reads
        # PENDING forever even with valid certs). With these aliases the fetch hits
        # the ingress controller's ClusterIP directly, still with SNI=<domain>, so
        # nginx serves the real cert and TLS terminates in-cluster. Only set in the
        # cloud (var is empty on local, where the check is HTTP anyway).
        dynamic "host_aliases" {
          for_each = var.internal_ingress_ip == "" ? [] : [1]
          content {
            ip = var.internal_ingress_ip
            hostnames = [
              var.public_base_domain,
              "sales.${var.public_base_domain}",
              "admin.${var.public_base_domain}",
              "dashboard.${var.public_base_domain}",
            ]
          }
        }

        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "dashboard"
          image = "ghcr.io/mockten/dashboard:latest"
          port {
            container_port = 3001
          }
          # The dashboard also auto-detects k8s from KUBERNETES_SERVICE_HOST, but
          # being explicit keeps the runtime choice visible here.
          #
          # DO NOT delete this in favour of MOCKTEN_MODE below. DEV_MODE says how
          # to inspect containers (false = k8s API, true = Docker socket) and is
          # false in BOTH local k8s and GKE. MOCKTEN_MODE says which deployment
          # shape this is, and differs between them. Folding the two together
          # sends local k8s looking for a Docker socket and kills Container List,
          # Log Viewer and Terminal.
          env {
            name  = "DEV_MODE"
            value = "false"
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
          dynamic "env" {
            for_each = var.session_secret_enabled ? [1] : []
            content {
              name = "DASHBOARD_SESSION_SECRET"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.dashboard_session[0].metadata[0].name
                  key  = "session_secret"
                }
              }
            }
          }
          env {
            name  = "K8S_NAMESPACE"
            value = "default"
          }
          # These three all default to docker-compose container names, which do
          # not resolve in-cluster (the platform convention is <name>-service).
          env {
            name  = "APIGW_BASE_URL"
            value = "http://apigw-service.default.svc.cluster.local:8082"
          }
          env {
            name  = "KONG_ADMIN_URL"
            value = "http://apigw-service.default.svc.cluster.local:8001"
          }
          env {
            name  = "AIRFLOW_BASE_URL"
            value = "http://airflow-webserver-service.default.svc.cluster.local:8080/api/v1"
          }
          env {
            name  = "AIRFLOW_USER"
            value = "airflow"
          }
          env {
            name  = "AIRFLOW_PASSWORD"
            value = "airflow"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "dashboard" {
  metadata {
    name      = "dashboard-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "dashboard"
    }
    port {
      name        = "http"
      port        = 3001
      target_port = 3001
    }
  }
}
