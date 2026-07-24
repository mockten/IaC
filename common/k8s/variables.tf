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

variable "namespace_memory_quota" {
  description = "Memory budget for the namespace. The dashboard reads it as the denominator for Total Memory Usage, which is otherwise the dashboard's own node — wrong once pods span nodes."
  type        = string
  default     = "8Gi"
}

# ── Per-environment knobs. Defaults reproduce docker-desktop exactly, so `local`
#    is unchanged; `gcp`/`azure`/`aws` override them. ──────────────────────────

variable "storage_class" {
  description = "StorageClass for stateful PVCs (mysql, minio). hostpath on docker-desktop; standard-rwo on GKE."
  type        = string
  default     = "hostpath"
}

variable "kc_hostname" {
  description = "Keycloak public hostname. localhost locally; the primary domain behind real HTTPS."
  type        = string
  default     = "localhost"
}

variable "kc_dev_mode" {
  description = "Keycloak DEV_MODE flag. true locally; false behind real TLS."
  type        = string
  default     = "true"
}

variable "public_origins" {
  description = "Public origins the app is served from (scheme+host, no trailing slash). Become the realm's webOrigins, and redirectUris with /* appended. Every host a login lands on must be here."
  type        = list(string)
  default     = ["http://localhost", "http://nginx"]
}

# MOCKTEN_MODE is deployment shape; DEV_MODE (above, and hard-coded false in the
# dashboard module) is how a container is inspected. They are NOT the same axis
# and must not be collapsed into one variable:
#
#   DEV (compose)  runtime=docker socket   deployment=dev
#   local k8s      runtime=k8s API         deployment=dev
#   GKE            runtime=k8s API         deployment=cloud
#
# Collapsing them breaks local k8s: "dev" would send the dashboard hunting for a
# Docker socket (Container List / Log Viewer / Terminal all die), and "k8s" would
# leave login-required undecidable.
variable "mockten_mode" {
  description = "Deployment shape: dev or cloud. cloud turns on dashboard login, host-split links, and the HTTPS READY condition. Leave dev for local k8s."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "cloud"], var.mockten_mode)
    error_message = "mockten_mode must be \"dev\" or \"cloud\"."
  }
}

variable "public_base_domain" {
  description = "Bare public domain (no scheme, no trailing slash), e.g. example.com. Required when mockten_mode is cloud: uam refuses to start without it rather than importing a realm that would fail every login."
  type        = string
  default     = ""

  validation {
    condition     = !can(regex("^https?://|/$", var.public_base_domain))
    error_message = "public_base_domain must be a bare hostname — no scheme, no trailing slash."
  }
}

# Split from the value below because a count/for_each may not depend on anything
# unknown at plan time, and the value is typically a random_password.
variable "dashboard_session_secret_enabled" {
  description = "Whether to manage a dashboard session signing key. Plan-time constant."
  type        = bool
  default     = false
}

# The uam image ships admin/admin as a default. Not currently reachable (the
# ingress does not route /admin/, and it is IP-allowlisted), but a weak default
# on an internet-facing deployment is worth removing while we are here.
variable "kc_admin_user" {
  description = "Keycloak master-realm admin username. Overrides the image default."
  type        = string
  default     = "admin"
}

variable "kc_admin_password" {
  description = "Keycloak master-realm admin password. Overrides the image default; generated in cloud."
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "e2e_admin_enabled" {
  description = "Create a dedicated admin account for the cloud E2E suite. Plan-time constant."
  type        = bool
  default     = false
}

variable "e2e_admin_user" {
  description = "Username/email of the E2E admin. Not a personal address."
  type        = string
  default     = ""
}

variable "e2e_admin_password" {
  description = "Password for the E2E admin. Generated, never committed."
  type        = string
  sensitive   = true
  default     = ""
}

variable "internal_ingress_ip" {
  description = "ClusterIP of the ingress-nginx controller, passed through to the dashboard so its readiness HTTPS check terminates TLS in-cluster (avoids the external-LB hairpin). Empty on local."
  type        = string
  default     = ""
}

variable "enable_seed_job" {
  description = "Run the in-cluster behavior-seeder Job after apply. Cloud roots set true so a fresh cluster trains the recommendation model; local leaves it false and seeds via the Taskfile instead."
  type        = bool
  default     = false
}

variable "seeder_image" {
  description = "One-shot behavior-seeder image (mockten-published). Only used when enable_seed_job is true."
  type        = string
  default     = "ghcr.io/mockten/seeder:latest"
}

variable "dashboard_session_secret" {
  description = "Signing key for dashboard login sessions. Ignored unless dashboard_session_secret_enabled. Unmanaged means the container generates one per start, which logs everyone out on restart."
  type        = string
  sensitive   = true
  default     = ""
}
