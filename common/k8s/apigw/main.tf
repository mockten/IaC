resource "kubernetes_deployment" "apigw" {
  metadata {
    name      = "apigw-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "apigw"
      }
    }
    template {
      metadata {
        labels = {
          app = "apigw"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        container {
          name  = "apigw"
          image = "ghcr.io/mockten/apigw:${var.image_tag}"
          port {
            container_port = 80
          }
          env {
            name  = "KONG_DNS_RESOLVER"
            value = ""
          }
          # Kong's access log, in the format the dashboard's API Gateway
          # telemetry parses. docker-compose sets these; without them Kong logs a
          # default line with no `rt=`, so the "Slowest APIs" tab has no response
          # times to rank by. The `$` are nginx variables, not Terraform ones.
          env {
            name  = "KONG_NGINX_HTTP_LOG_FORMAT"
            value = "with_rt '$remote_addr - $remote_user [$time_local] \"$request\" $status $body_bytes_sent rt=$upstream_response_time kong_request_id: \"$kong_request_id\"'"
          }
          env {
            name  = "KONG_PROXY_ACCESS_LOG"
            value = "/tmp/access.log with_rt"
          }
          # Kong idles ~165MiB and bursts past 360MiB; compose caps it at 600m and
          # tunes these down to match. Keep them in step so behaviour is the same.
          env {
            name  = "KONG_MEM_CACHE_SIZE"
            value = "32m"
          }
          env {
            name  = "KONG_LOG_LEVEL"
            value = "warn"
          }
          env {
            name  = "KONG_NGINX_WORKER_PROCESSES"
            value = "1"
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "apigw" {
  metadata {
    name      = "apigw-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "apigw"
    }
    port {
      name        = "http"
      port        = 80
      target_port = 8082
    }
    # Kong also listens on 8082 (proxy) and 8001 (admin) inside the pod, which
    # docker-compose publishes. The dashboard's APIGW_BASE_URL / KONG_ADMIN_URL
    # point at these, so both have to be reachable as services, not just via the
    # ingress on :80.
    port {
      name        = "proxy"
      port        = 8082
      target_port = 8082
    }
    port {
      name        = "admin"
      port        = 8001
      target_port = 8001
    }
  }
}
