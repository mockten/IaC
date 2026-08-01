# Route53 hosted zone + the nameserver push to the registrar. Same design as
# gcp/dns and azure/dns.
#
# The A/ALIAS records that point the four hostnames at the load balancer live in
# platform/records.tf, NOT here. That split is deliberate: cert-manager (in
# platform) needs this zone's id, and the records need the load balancer's
# hostname (also from platform). Keeping the records here as well would make dns
# and platform reference each other — a module cycle Terraform rejects. The zone
# has no dependency on platform, so it stays; the records follow the hostname.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    # PATCHes the registrar's nameservers over its REST API (no official provider).
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "~> 1.2"
    }
  }
}

resource "aws_route53_zone" "zone" {
  name          = var.root_domain
  comment       = "mockten — managed by terraform"
  force_destroy = true # a zone with records left in it otherwise blocks destroy
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
