# Azure Front Door (Standard) in front of the Application Gateway — the Azure
# counterpart to aws/cdn (CloudFront). Edge-caches the static, high-bandwidth
# paths (product images at /api/storage/*, the SPA's /assets/*) and passes dynamic
# requests straight through. Managed TLS certificates (free, auto-renewing) are the
# ACM/CloudFront-managed-cert equivalent.
#
# Standard has no WAF, so the per-user IP restriction lives on the App Gateway WAF
# (../appgw). Front Door reaches the gateway over HTTP; leaving origin_host_header
# unset makes Front Door forward the incoming host, so AGIC still host-routes.
# This module also owns the Front Door DNS records (the four hostnames alias Front
# Door, not the gateway).
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "${var.name_prefix}-fd"
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = "${var.name_prefix}-fd-ep"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}

resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = "appgw"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  load_balancing {}
  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Http"
    request_type        = "HEAD"
  }
}

resource "azurerm_cdn_frontdoor_origin" "appgw" {
  name                          = "appgw"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                       = true

  # HTTP to the gateway (Front Door terminates TLS). origin_host_header omitted so
  # Front Door forwards the client's host and AGIC can route by hostname.
  host_name                      = var.appgw_fqdn
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = false
}

# ── Custom domains (managed TLS, validated in the Azure DNS zone) ─────────────
locals {
  domains = {
    apex      = var.host_store
    sales     = var.host_sales
    admin     = var.host_admin
    dashboard = var.host_dashboard
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "this" {
  for_each                 = local.domains
  name                     = "cd-${each.key}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  dns_zone_id              = var.dns_zone_id
  host_name                = each.value

  tls {
    certificate_type = "ManagedCertificate"
  }
}

# ── Routes: cache the static paths, pass everything else through ─────────────
resource "azurerm_cdn_frontdoor_route" "static" {
  name                            = "static-cache"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.appgw.id]
  cdn_frontdoor_custom_domain_ids = [for d in azurerm_cdn_frontdoor_custom_domain.this : d.id]

  enabled                = true
  forwarding_protocol    = "HttpOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/api/storage/*", "/assets/*"]
  supported_protocols    = ["Http", "Https"]
  link_to_default_domain = false

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
  }
}

resource "azurerm_cdn_frontdoor_route" "dynamic" {
  name                            = "dynamic"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.appgw.id]
  cdn_frontdoor_custom_domain_ids = [for d in azurerm_cdn_frontdoor_custom_domain.this : d.id]

  enabled                = true
  forwarding_protocol    = "HttpOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
  link_to_default_domain = false
}

# ── DNS: validation TXT + the hostnames aliasing Front Door ───────────────────
resource "azurerm_dns_txt_record" "validation" {
  for_each            = azurerm_cdn_frontdoor_custom_domain.this
  name                = "_dnsauth.${replace(each.value.host_name, ".${var.dns_zone_name}", "")}"
  zone_name           = var.dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  record {
    value = each.value.validation_token
  }
}

# Subdomains: CNAME to the Front Door endpoint.
resource "azurerm_dns_cname_record" "sub" {
  for_each            = { for k, v in local.domains : k => v if k != "apex" }
  name                = replace(each.value, ".${var.dns_zone_name}", "")
  zone_name           = var.dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  record              = azurerm_cdn_frontdoor_endpoint.this.host_name
}

# Apex: CNAME is illegal at the zone root, so use an Azure DNS alias A record that
# targets the Front Door endpoint.
resource "azurerm_dns_a_record" "apex" {
  name                = "@"
  zone_name           = var.dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_cdn_frontdoor_endpoint.this.id
}
