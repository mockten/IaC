variable "secret_name" {
  description = "The name of the Kubernetes secret for image pull"
  type        = string
}

variable "stripe_public_key" {
  description = "Stripe publishable key, rendered into /config.js at container start-up"
  type        = string
  default     = ""
}

variable "mockten_mode" {
  description = "dev or cloud. cloud splits the portals across sales./admin./dashboard. subdomains and hides the auth backdoor link."
  type        = string
  default     = "dev"
}

variable "public_base_domain" {
  description = "Bare public domain the portal links are derived from. Empty in dev."
  type        = string
  default     = ""
}
variable "image_tag" {
  description = "Image tag to deploy for this service (e.g. \"1.64\" or \"latest\")."
  type        = string
  default     = "latest"
}
