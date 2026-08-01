output "acm_certificate_arn" {
  description = "The validated in-region ACM cert the ALB serves for the four hostnames."
  value       = aws_acm_certificate_validation.ingress.certificate_arn
}
