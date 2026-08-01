output "distribution_domain_name" {
  description = "The CloudFront domain the four hostnames alias to."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}
