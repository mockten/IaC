variable "secret_name" {
  description = "The name of the Kubernetes secret for image pull"
  type        = string
}

variable "mockten_mode" {
  description = "dev or cloud. cloud puts a login in front of the dashboard and adds the HTTPS READY condition. Orthogonal to DEV_MODE, which stays false here because this is always k8s."
  type        = string
  default     = "dev"
}

variable "public_base_domain" {
  description = "Bare public domain. Empty in dev."
  type        = string
  default     = ""
}

# Two variables, deliberately. Whether to manage a session key is configuration
# and is known at plan time; the key itself may be a random_password, whose value
# is unknown until apply. Deriving the count from the value instead fails the
# whole plan with "count depends on resources that cannot be determined until
# apply" — including `terraform destroy`, which is how this was found.
variable "session_secret_enabled" {
  description = "Whether to manage a session signing key at all. Must be a plan-time constant."
  type        = bool
  default     = false
}

variable "session_secret" {
  description = "Signing key for login sessions. Ignored unless session_secret_enabled. When unmanaged the container generates one per start, logging everyone out on restart."
  type        = string
  sensitive   = true
  default     = ""
}
