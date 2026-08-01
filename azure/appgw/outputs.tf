output "id" {
  description = "Application Gateway resource id — consumed by the AKS AGIC add-on."
  value       = azurerm_application_gateway.this.id
}

output "name" {
  value = azurerm_application_gateway.this.name
}

output "public_ip" {
  value = azurerm_public_ip.appgw.ip_address
}

output "fqdn" {
  description = "The gateway's public FQDN — used as the Front Door origin host."
  value       = azurerm_public_ip.appgw.fqdn
}
