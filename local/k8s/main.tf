resource "kubernetes_persistent_volume" "local" {
  metadata {
    name = "local-pv"
  }
  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    volume_mode = "Filesystem"
    persistent_volume_source {
      host_path {
        path = "/mnt/data"
      }
    }
  }
}


resource "kubernetes_persistent_volume_claim" "local" {
  metadata {
    name = "local-pvc"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_pod" "local" {
  metadata {
    name = "local-pv-pod"
  }
  spec {
    container {
      name  = "local-pv-container"
      image = "nginx"
      volume_mount {
        mount_path = "/usr/share/nginx/html"
        name       = "local-storage"
      }
    }
    volume {
      name = "local-storage"
      persistent_volume_claim {
        claim_name = "local-pvc"
      }
    }
  }
}
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
          args  = [
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
    name = "ecfront-ingress"
    namespace = "default"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "localhost"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "ecfront-service"
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

resource "kubernetes_ingress_class_v1" "nginx" {
  metadata {
    name = "nginx"
  }
  spec {
    controller = "k8s.io/ingress-nginx"
  }
}
