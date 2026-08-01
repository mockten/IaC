output "alb_dns_name" {
  description = "The shared ALB hostname CloudFront uses as its origin."
  value       = data.aws_lb.ingress.dns_name
}
