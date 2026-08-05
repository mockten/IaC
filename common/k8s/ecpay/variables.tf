variable "secret_name" {
  description = "The name of the Kubernetes secret for image pull"
  type        = string
}

variable "stripe_secret_key" {
  description = "Stripe secret key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "image_tag" {
  description = "Image tag to deploy for this service (e.g. \"1.64\" or \"latest\")."
  type        = string
  default     = "latest"
}
