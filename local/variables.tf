variable "kube_context" {
  description = "kubectl context the local root applies to. Defaults to docker-desktop so `local` can never touch a cloud cluster by accident; CI overrides it (TF_VAR_kube_context=minikube) to plan against the minikube it starts."
  type        = string
  default     = "docker-desktop"
}

variable "github_username" {
  description = "GitHub username"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_email" {
  description = "GitHub email"
  type        = string
}

variable "google_client_id" {
  description = "Google OAuth client ID"
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "facebook_client_id" {
  description = "Facebook OAuth client ID"
  type        = string
  default     = ""
}

variable "facebook_client_secret" {
  description = "Facebook OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "stripe_secret_key" {
  description = "Stripe secret key for payment processing"
  type        = string
  sensitive   = true
  default     = ""
}

# Not marked sensitive: this one is the publishable key, which is served to every
# visitor in /config.js by design.
variable "stripe_public_key" {
  description = "Stripe publishable key, supplied to the ecfront container at start-up"
  type        = string
  default     = ""
}
