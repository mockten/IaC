output "endpoint_hostname" {
  description = "The Front Door endpoint the four hostnames alias to."
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
}
