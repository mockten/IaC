# DNS zone, host records and the registrar nameserver push — the Azure
# counterpart to gcp/dns.
terraform {
  required_providers {
    azurerm   = { source = "hashicorp/azurerm" }
    terracurl = { source = "devops-rob/terracurl" }
  }
}

resource "azurerm_dns_zone" "zone" {
  name                = var.root_domain
  resource_group_name = var.resource_group_name
}

# The host records (CNAME/alias to Front Door) and the managed-cert validation TXT
# live in ../cdn — they alias Front Door, not the gateway, and need Front Door's
# endpoint + validation tokens. This module keeps only the zone and the delegation.

# Same registrar push as the other clouds. Two hard-won details carried over: the
# WAF rejects non-browser User-Agents (and the rejection looks like an auth
# failure), and there is deliberately no destroy_* block — the destroy call
# returns text/html, which terracurl cannot deserialise, and that blocks
# `terraform destroy` entirely.
resource "terracurl_request" "ns_delegation" {
  count  = var.enable_ns_push ? 1 : 0
  name   = "ns-delegation"
  url    = "${var.domain_api_base_url}/domains/${var.root_domain}/nameservers"
  method = "PATCH"

  headers = {
    Authorization = "Bearer ${var.domain_api_key}"
    Content-Type  = "application/json"
    Accept        = "application/json"
    User-Agent    = var.domain_api_user_agent
  }

  request_body   = jsonencode({ nameservers = azurerm_dns_zone.zone.name_servers })
  response_codes = ["200", "201", "202", "204"]

  lifecycle {
    replace_triggered_by = [azurerm_dns_zone.zone]
  }
}
