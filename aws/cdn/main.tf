# Full-site CloudFront in front of the ALB. Caches the static, high-bandwidth
# paths (product images at /api/storage/*, the SPA's built assets) at the edge and
# passes dynamic requests straight through. No mockten change: the viewer URLs are
# unchanged, CloudFront just fronts the same hostnames.
#
# Privacy is preserved by a WAFv2 IP-set (the operator allowlist + the cluster's
# NAT egress IP, so the dashboard's own readiness check still passes). The ALB is
# separately locked to CloudFront's origin-facing prefix list (see routing/), so it
# cannot be reached directly, bypassing the WAF.
#
# The viewer certificate and the WebACL are CloudFront-scoped and MUST be in
# us-east-1 — hence the aws.us_east_1 provider passed in from the root.

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.60"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# ── us-east-1 viewer certificate ─────────────────────────────────────────────
resource "aws_acm_certificate" "cdn" {
  provider                  = aws.us_east_1
  domain_name               = var.host_store
  subject_alternative_names = [var.host_sales, var.host_admin, var.host_dashboard]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cdn.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cdn" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cdn.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ── WAF: allow only the operator IP(s) + the cluster NAT egress ───────────────
resource "aws_wafv2_ip_set" "allow" {
  provider           = aws.us_east_1
  name               = "mockten-cdn-allow"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses = concat(
    [for c in split(",", var.allowlist_cidr) : trimspace(c)],
    ["${var.nat_public_ip}/32"],
  )
}

resource "aws_wafv2_web_acl" "cdn" {
  provider = aws.us_east_1
  name     = "mockten-cdn"
  scope    = "CLOUDFRONT"
  default_action {
    block {}
  }
  rule {
    name     = "allow-ip-set"
    priority = 0
    action {
      allow {}
    }
    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.allow.arn
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "mockten-cdn-allow"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "mockten-cdn"
    sampled_requests_enabled   = true
  }
}

# ── Cache/origin-request policies (managed) ──────────────────────────────────
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}
# Forwards every viewer header (incl. Host, so the ALB host-routes), cookie and
# query string to the origin — required for the dynamic app and Keycloak.
data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

# ── Distribution ─────────────────────────────────────────────────────────────
resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "mockten"
  aliases         = [var.host_store, var.host_sales, var.host_admin, var.host_dashboard]
  web_acl_id      = aws_wafv2_web_acl.cdn.arn
  price_class     = "PriceClass_200"

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb"
    # HTTP to the origin on purpose: CloudFront terminates TLS with the us-east-1
    # cert and forces viewers onto HTTPS. Going HTTPS to the origin would make
    # CloudFront validate the ALB's cert against the ALB's own *.elb hostname,
    # which the mockten cert does not cover -> 502. The hop is private (ALB is
    # locked to CloudFront's prefix list).
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Dynamic by default: no caching, forward everything.
  default_cache_behavior {
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    compress                 = true
  }

  # Product images: stable URLs, immutable content — cache at the edge.
  ordered_cache_behavior {
    path_pattern             = "/api/storage/*"
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    compress                 = true
  }

  # The SPA's built assets (hashed filenames) — cache long.
  ordered_cache_behavior {
    path_pattern             = "/assets/*"
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    compress                 = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cdn.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# ── DNS: the four hostnames now alias CloudFront (not the ALB) ────────────────
locals {
  record_hosts = {
    apex      = var.host_store
    sales     = var.host_sales
    admin     = var.host_admin
    dashboard = var.host_dashboard
  }
}

resource "aws_route53_record" "a" {
  for_each = local.record_hosts
  zone_id  = var.route53_zone_id
  name     = each.value
  type     = "A"
  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
