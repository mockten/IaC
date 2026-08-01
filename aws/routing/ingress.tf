# Host-based ALB routing. All four Ingresses share ONE ALB via the IngressGroup
# annotation (group.name); the controller merges their rules onto a single load
# balancer. Same host/path map as gcp/azure's nginx Ingress — only the mechanism
# (ALB rules vs nginx) differs.

locals {
  alb_base_annotations = {
    "alb.ingress.kubernetes.io/group.name"   = "mockten"
    "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"  = "ip"
    "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
    # TLS is terminated at CloudFront, which reaches the ALB over HTTP; the ACM
    # cert is still bound to the 443 listener for a direct-HTTPS fallback. No
    # ssl-redirect: CloudFront enforces HTTPS to viewers, and redirecting the
    # HTTP origin hop would loop.
    "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
    # Accept traffic only from CloudFront's edges (self-managed frontend SG in
    # main.tf), never directly — that would bypass the WAF. This replaces
    # inbound-cidrs, which cannot reference a managed prefix list.
    "alb.ingress.kubernetes.io/security-groups"                     = aws_security_group.alb_frontend.id
    "alb.ingress.kubernetes.io/manage-backend-security-group-rules" = "true"
    "alb.ingress.kubernetes.io/healthcheck-path"                    = "/"
    # Backends differ (Kong, Keycloak, the SPA); several answer non-200 at "/".
    # Treat any HTTP response as healthy so a target group is never marked down
    # just because its service does not serve 200 at the health path.
    "alb.ingress.kubernetes.io/success-codes" = "200-499"
  }

  ecfront_paths = [
    { path = "/api/test/", svc = "backdoor-service", port = 8080 },
    { path = "/api/", svc = "apigw-service", port = 80 },
    { path = "/realms/mockten-realm-dev/broker/", svc = "uam-service", port = 80 },
    { path = "/realms/mockten-realm-dev/login-actions/", svc = "uam-service", port = 80 },
    { path = "/resources/", svc = "uam-service", port = 80 },
    { path = "/", svc = "ecfront-service", port = 80 },
  ]

  # store has no app-root redirect; sales/admin redirect "/" to their app root.
  ecfront_hosts = {
    store = { host = var.host_store, app_root = null }
    sales = { host = var.host_sales, app_root = "/seller/login" }
    admin = { host = var.host_admin, app_root = "/admin" }
  }
}

resource "kubernetes_ingress_v1" "ecfront" {
  for_each = local.ecfront_hosts

  metadata {
    name      = "ecfront-${each.key}"
    namespace = "default"
    annotations = merge(
      local.alb_base_annotations,
      each.value.app_root == null ? {} : {
        # ALB redirect action consumed by the "/" Exact rule below.
        "alb.ingress.kubernetes.io/actions.root-redirect" = jsonencode({
          Type = "redirect"
          RedirectConfig = {
            Path       = each.value.app_root
            StatusCode = "HTTP_302"
          }
        })
      }
    )
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = each.value.host
      http {
        # For sales/admin: an Exact "/" that hits the redirect action, ahead of
        # the Prefix "/" that serves the SPA. ALB ranks the exact match higher.
        dynamic "path" {
          for_each = each.value.app_root == null ? [] : [1]
          content {
            path      = "/"
            path_type = "Exact"
            backend {
              service {
                name = "root-redirect"
                port { name = "use-annotation" }
              }
            }
          }
        }
        dynamic "path" {
          for_each = local.ecfront_paths
          content {
            path      = path.value.path
            path_type = "Prefix"
            backend {
              service {
                name = path.value.svc
                port { number = path.value.port }
              }
            }
          }
        }
      }
    }
  }
}

# Dashboard: served at the root of its own host, no redirect.
resource "kubernetes_ingress_v1" "dashboard" {
  metadata {
    name        = "dashboard"
    namespace   = "default"
    annotations = local.alb_base_annotations
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = var.host_dashboard
      http {
        path {
          path      = "/"
          path_type = "Prefix"
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
