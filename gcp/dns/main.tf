# Cloud DNS zone for the domain, A records for the four hosts pointing at the
# ingress LB IP, and an automatic nameserver-delegation push to the registrar.

resource "google_dns_managed_zone" "zone" {
  name        = replace(var.root_domain, ".", "-")
  dns_name    = "${var.root_domain}."
  description = "mockten"
}

locals {
  hosts = {
    apex      = "${var.root_domain}."
    sales     = "sales.${var.root_domain}."
    admin     = "admin.${var.root_domain}."
    dashboard = "dashboard.${var.root_domain}."
  }
}

resource "google_dns_record_set" "a" {
  for_each     = local.hosts
  name         = each.value
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.zone.name
  rrdatas      = [var.ingress_ip]
}

# Push the zone's assigned nameservers to the DigitalPlat registrar so the domain
# delegates here with no manual step — this is what makes the whole apply
# CD-pipeline-able.
#
# The User-Agent and Accept headers are REQUIRED, not cosmetic: the API sits
# behind a WAF that serves a Cloudflare challenge page (403 text/html) to
# requests with a default client user-agent. With a normal browser UA the API
# authenticates the bearer token and responds JSON. Drop those headers and every
# apply fails with "serializer for text/html doesn't exist".
#
# The token comes from var.domain_api_key (TF_VAR_domain_api_key ← .env /
# GitHub secret) and is never committed.
#
# No destroy_* block on purpose: teardown should leave the delegation alone
# (there is nothing meaningful to revert to), and terracurl's destroy call would
# otherwise fail on the same text/html and block `terraform destroy`. Re-applying
# re-pushes whatever nameservers the recreated zone gets, so it self-heals.
resource "terracurl_request" "ns_delegation" {
  count  = var.enable_ns_push ? 1 : 0
  name   = "ns-delegation"
  url    = "${var.domain_api_base_url}/domains/${var.root_domain}/nameservers"
  method = "PATCH"
  request_body = jsonencode({
    nameservers = [for ns in google_dns_managed_zone.zone.name_servers : trimsuffix(ns, ".")]
  })
  headers = {
    Authorization = "Bearer ${var.domain_api_key}"
    Content-Type  = "application/json"
    Accept        = "application/json"
    User-Agent    = var.domain_api_user_agent
  }
  response_codes = ["200", "201", "202", "204"]
}
