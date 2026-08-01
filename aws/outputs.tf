output "cluster_name" {
  value = module.eks.cluster_name
}

output "alb_hostname" {
  description = "The shared ALB hostname (CloudFront's origin; not user-facing)."
  value       = module.routing.alb_dns_name
}

output "cdn_domain" {
  description = "The CloudFront domain the four hostnames alias to."
  value       = module.cdn.distribution_domain_name
}

output "name_servers" {
  description = "Route53 nameservers pushed to the registrar for delegation."
  value       = module.dns.name_servers
}

output "hosts" {
  value = {
    storefront = "https://${local.host_store}"
    sales      = "https://${local.host_sales}"
    admin      = "https://${local.host_admin}"
    dashboard  = "https://${local.host_dashboard}"
  }
}

# Feed the E2E suite with:
#   export DASHBOARD_ADMIN_USER=$(terraform output -raw e2e_admin_user)
#   export DASHBOARD_ADMIN_PASSWORD=$(terraform output -raw e2e_admin_password)
# so the credentials go from state straight into the runner's environment and
# never land in a file, a document, or a chat message.
output "e2e_admin_user" {
  value = "e2e-admin@${var.root_domain}"
}

output "e2e_admin_password" {
  value     = random_password.e2e_admin.result
  sensitive = true
}

output "kc_admin_password" {
  description = "Keycloak master-realm admin password, replacing the image's admin/admin default."
  value       = random_password.kc_admin.result
  sensitive   = true
}
