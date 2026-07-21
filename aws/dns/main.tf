# Route53 hosted zone + the four A records, and the nameserver push to the
# registrar. Same design as gcp/dns.

variable "root_domain" { type = string }
variable "ingress_hostname" {
  description = "The NLB's DNS name. AWS load balancers get a hostname, not a static IP, so these are ALIAS/CNAME records rather than the A records used on GCP."
  type        = string
}
variable "ingress_zone_id" { type = string }
variable "domain_api_base_url" { type = string }
variable "domain_api_key" {
  type      = string
  sensitive = true
}
variable "domain_api_user_agent" { type = string }
variable "enable_ns_push" { type = bool }

resource "aws_route53_zone" "zone" {
  name          = var.root_domain
  comment       = "mockten — managed by terraform"
  force_destroy = true # a zone with records left in it otherwise blocks destroy
}

locals {
  hosts = {
    apex      = var.root_domain
    sales     = "sales.${var.root_domain}"
    admin     = "admin.${var.root_domain}"
    dashboard = "dashboard.${var.root_domain}"
  }
}

# ALIAS records, not CNAME: the apex cannot be a CNAME, and ALIAS costs nothing
# to resolve. All four point at the same NLB; nginx routes by Host header.
resource "aws_route53_record" "a" {
  for_each = local.hosts
  zone_id  = aws_route53_zone.zone.zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = var.ingress_hostname
    zone_id                = var.ingress_zone_id
    evaluate_target_health = false
  }
}

# The registrar exposes a REST API but no Terraform provider, so this is a raw
# PATCH. Two things learned the hard way on GCP and carried over:
#
#   * The WAF rejects non-browser User-Agents outright, and the rejection looks
#     exactly like an auth failure. Send a browser UA.
#   * No destroy_* block. The destroy call returns text/html, which terracurl
#     cannot deserialise, and that failure blocks `terraform destroy` entirely.
#     Delegation is left pointing at a dead zone until the next apply, which is
#     harmless — nothing else resolves the domain.
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

  request_body = jsonencode({
    nameservers = aws_route53_zone.zone.name_servers
  })

  response_codes = ["200", "201", "202", "204"]

  # Re-push whenever the zone is recreated: a new zone means new nameservers,
  # and a stale delegation means certificates can never be issued again.
  lifecycle {
    replace_triggered_by = [aws_route53_zone.zone]
  }
}

output "zone_id" { value = aws_route53_zone.zone.zone_id }
output "name_servers" { value = aws_route53_zone.zone.name_servers }
