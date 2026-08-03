output "ingress_ip" {
  description = "The IP the four A records point at; the only IP the LB firewall admits."
  value       = google_compute_address.ingress.address
}

output "name_servers" {
  description = "Cloud DNS name servers pushed to the registrar for delegation."
  value       = module.dns.name_servers
}

output "cluster_name" {
  value = module.gke.name
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
# so the credentials go straight from state into the runner's environment and
# never land in a file, a document, or a chat message.
output "e2e_admin_user" {
  description = "Username for the E2E dashboard login."
  value       = "e2e-admin@${var.root_domain}"
}

output "e2e_admin_password" {
  description = "Password for the E2E dashboard login. Generated; read it with `terraform output -raw`."
  value       = random_password.e2e_admin.result
  sensitive   = true
}

output "kc_admin_password" {
  description = "Keycloak master-realm admin password, replacing the image's admin/admin default. Needed only to reach the Keycloak admin console, which is not exposed through the ingress."
  value       = random_password.kc_admin.result
  sensitive   = true
}
