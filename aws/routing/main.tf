# ALB routing: the host-based Ingresses (ingress.tf). Split out of platform/ on
# purpose — these must be created AFTER the workload Services exist (the AWS Load
# Balancer Controller builds a target group per backend and fails on a missing
# service), whereas the controller itself (platform/) must exist BEFORE any
# Service so its admission webhook has endpoints. So: platform -> common_k8s ->
# routing. The Route53 records live in cdn/ (they alias CloudFront, not the ALB).

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

# The ALB is fronted by CloudFront, so it must accept traffic ONLY from
# CloudFront's edge — never directly, which would bypass the WAF. AWS publishes
# those edge IPs as a managed prefix list; a self-managed frontend SG (attached to
# the ALB via the Ingress annotation) allows just that list. inbound-cidrs is not
# used because it takes CIDRs, not prefix lists.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb_frontend" {
  name        = "mockten-alb-frontend"
  description = "mockten ALB: allow only CloudFront origin-facing edges"
  vpc_id      = var.vpc_id

  # Port 80 only: CloudFront reaches this ALB over HTTP (it terminates TLS itself).
  # A second rule for 443 would double the prefix list's ~55 entries and blow past
  # the 60-rules-per-SG limit; the 443 listener is intentionally left unreachable.
  ingress {
    description     = "HTTP from CloudFront edges"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
