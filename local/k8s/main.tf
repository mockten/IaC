
# ── metrics-server ───────────────────────────────────────────────────────────
# Transcribed from the upstream components.yaml (v0.9.0). It is deployed here
# rather than with `kubectl apply -f` so that `terraform destroy` actually
# removes it: anything applied out of band survives the destroy and has to be
# cleaned up by hand.
#
# Managed clusters (AKS/GKE) ship metrics-server already, so this is local-only,
# like the ingress controller below. Without it the dashboard reports 0 for pod
# CPU/memory and every other panel still works.

locals {
  metrics_server_labels = {
    k8s-app = "metrics-server"
  }
}

resource "kubernetes_service_account" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels    = local.metrics_server_labels
  }
}

resource "kubernetes_cluster_role" "aggregated_metrics_reader" {
  metadata {
    name = "system:aggregated-metrics-reader"
    labels = merge(local.metrics_server_labels, {
      "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
      "rbac.authorization.k8s.io/aggregate-to-edit"  = "true"
      "rbac.authorization.k8s.io/aggregate-to-view"  = "true"
    })
  }
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role" "metrics_server" {
  metadata {
    name   = "system:metrics-server"
    labels = local.metrics_server_labels
  }
  rule {
    api_groups = [""]
    resources  = ["nodes/metrics"]
    verbs      = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

# Lets metrics-server read the extension-apiserver-authentication ConfigMap,
# which it needs to authenticate requests proxied from the API server.
resource "kubernetes_role_binding" "metrics_server_auth_reader" {
  metadata {
    name      = "metrics-server-auth-reader"
    namespace = "kube-system"
    labels    = local.metrics_server_labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "extension-apiserver-authentication-reader"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.metrics_server.metadata[0].name
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "metrics_server_auth_delegator" {
  metadata {
    name   = "metrics-server:system:auth-delegator"
    labels = local.metrics_server_labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.metrics_server.metadata[0].name
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "metrics_server" {
  metadata {
    name   = "system:metrics-server"
    labels = local.metrics_server_labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.metrics_server.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.metrics_server.metadata[0].name
    namespace = "kube-system"
  }
}

resource "kubernetes_service" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels    = local.metrics_server_labels
  }
  spec {
    selector = local.metrics_server_labels
    port {
      name        = "https"
      port        = 443
      protocol    = "TCP"
      target_port = "https"
    }
  }
}

resource "kubernetes_deployment" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
    labels    = local.metrics_server_labels
  }
  spec {
    selector {
      match_labels = local.metrics_server_labels
    }
    strategy {
      rolling_update {
        max_unavailable = 0
      }
    }
    template {
      metadata {
        labels = local.metrics_server_labels
      }
      spec {
        service_account_name            = kubernetes_service_account.metrics_server.metadata[0].name
        priority_class_name             = "system-cluster-critical"
        node_selector                   = { "kubernetes.io/os" = "linux" }
        automount_service_account_token = true

        container {
          name              = "metrics-server"
          image             = "registry.k8s.io/metrics-server/metrics-server:v0.9.0"
          image_pull_policy = "IfNotPresent"
          args = [
            "--cert-dir=/tmp",
            "--secure-port=10250",
            "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
            "--kubelet-use-node-status-port",
            "--metric-resolution=15s",
            # docker-desktop's kubelet serves a self-signed cert that
            # metrics-server will not trust, so it never becomes ready without
            # this. Not in upstream components.yaml.
            "--kubelet-insecure-tls",
          ]
          port {
            name           = "https"
            container_port = 10250
            protocol       = "TCP"
          }
          liveness_probe {
            http_get {
              path   = "/livez"
              port   = "https"
              scheme = "HTTPS"
            }
            period_seconds    = 10
            failure_threshold = 3
          }
          readiness_probe {
            http_get {
              path   = "/readyz"
              port   = "https"
              scheme = "HTTPS"
            }
            initial_delay_seconds = 20
            period_seconds        = 10
            failure_threshold     = 3
          }
          resources {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 1000
            capabilities {
              drop = ["ALL"]
            }
            seccomp_profile {
              type = "RuntimeDefault"
            }
          }
          volume_mount {
            name       = "tmp-dir"
            mount_path = "/tmp"
          }
        }
        volume {
          name = "tmp-dir"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_api_service_v1" "metrics" {
  metadata {
    name   = "v1beta1.metrics.k8s.io"
    labels = local.metrics_server_labels
  }
  spec {
    group                    = "metrics.k8s.io"
    group_priority_minimum   = 100
    version                  = "v1beta1"
    version_priority         = 100
    insecure_skip_tls_verify = true
    service {
      name      = kubernetes_service.metrics_server.metadata[0].name
      namespace = "kube-system"
    }
  }
}

# ── ingress-nginx ────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "kubernetes_service_account" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress-serviceaccount"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "nginx_ingress" {
  metadata {
    name = "nginx-ingress-clusterrole"
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps", "pods", "secrets", "endpoints", "services", "events"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "ingresses/status", "ingressclasses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "nginx_ingress" {
  metadata {
    name = "nginx-ingress-clusterrolebinding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.nginx_ingress.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.nginx_ingress.metadata[0].name
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }
}

resource "kubernetes_config_map" "nginx_configuration" {
  metadata {
    name      = "nginx-configuration"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }
  data = {
    enable-vts-status = "true"
  }
}

resource "kubernetes_deployment" "nginx_ingress_controller" {
  metadata {
    name      = "nginx-ingress-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
    labels = {
      app = "nginx-ingress"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "nginx-ingress"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx-ingress"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.nginx_ingress.metadata[0].name
        container {
          name  = "nginx-ingress-controller"
          image = "k8s.gcr.io/ingress-nginx/controller:v1.1.1"
          args = [
            "/nginx-ingress-controller",
            "--configmap=$(POD_NAMESPACE)/nginx-configuration",
            "--ingress-class=nginx"
          ]
          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          port {
            name           = "http"
            container_port = 80
          }
          port {
            name           = "https"
            container_port = 443
          }
          liveness_probe {
            http_get {
              path = "/healthz"
              port = 10254
            }
            initial_delay_seconds = 10
            timeout_seconds       = 1
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = 10254
            }
            initial_delay_seconds = 10
            timeout_seconds       = 1
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }
  wait_for_load_balancer = false
  spec {
    type = "LoadBalancer"
    selector = {
      app = "nginx-ingress"
    }
    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
    port {
      name        = "https"
      port        = 443
      target_port = 443
    }
  }
}

resource "kubernetes_ingress_v1" "ecfront" {
  metadata {
    name      = "ecfront-ingress"
    namespace = "default"
    annotations = {
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "localhost"
      http {
        path {
          path      = "/api/test/"
          path_type = "Prefix"
          backend {
            service {
              name = "backdoor-service"
              port {
                number = 8080
              }
            }
          }
        }
        path {
          path = "/api/"
          backend {
            service {
              name = "apigw-service"
              port { number = 80 }
            }
          }
        }
        path {
          path = "/"
          backend {
            service {
              name = "ecfront-service"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/realms/mockten-realm-dev/broker/"
          path_type = "Prefix"
          backend {
            service {
              name = "uam-service"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/realms/mockten-realm-dev/login-actions/"
          path_type = "Prefix"
          backend {
            service {
              name = "uam-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "dashboard" {
  metadata {
    name      = "dashboard-ingress"
    namespace = "default"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$1"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "localhost"
      http {
        path {
          path      = "/dashboard/(.*)"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "dashboard-service"
              port { number = 3001 }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_class_v1" "nginx" {
  metadata {
    name = "nginx"
  }
  spec {
    controller = "k8s.io/ingress-nginx"
  }
}
