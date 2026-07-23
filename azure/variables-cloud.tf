# Variables for the AKS draft in aks.tf. Kept separate from variables.tf, which
# belongs to the older VM-based design still present in this directory.
#
# Same contract as gcp and aws: anything operator-specific has NO default, so it
# must arrive through TF_VAR_* and can never be committed.

variable "allowlist_cidr" {
  description = "CIDR(s) allowed to reach the HTTPS ingress AND the AKS API server. Comma-separated for multiple people, e.g. \"1.2.3.4/32,5.6.7.8/32\" (surrounding spaces are trimmed). TF_VAR_allowlist_cidr ← ALLOWLIST_CIDR."
  type        = string
}

variable "master_authorized_extra" {
  description = "Extra CIDRs for the API server only (e.g. the CI runner's egress IP, per-run). Never opened on the ingress."
  type        = list(string)
  default     = []
}

variable "root_domain" {
  description = "Apex domain served by the storefront, no trailing dot."
  type        = string
}

variable "letsencrypt_email" {
  description = "ACME account email for Let's Encrypt expiry notices."
  type        = string
}

variable "domain_api_base_url" {
  type    = string
  default = "https://domain-api.digitalplat.org/api/v1"
}

variable "domain_api_key" {
  type      = string
  sensitive = true
}

variable "domain_api_user_agent" {
  description = "The registrar's WAF rejects non-browser agents, and the rejection looks like an auth failure."
  type        = string
  default     = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
}

variable "enable_ns_push" {
  type    = bool
  default = true
}

variable "acme_staging" {
  description = "Issue from Let's Encrypt staging while iterating. Production allows only 5 certificates per identifier set per 168h."
  type        = bool
  default     = false
}

variable "namespace_memory_quota" {
  type    = string
  default = "16Gi"
}

variable "github_username" { type = string }
variable "github_token" {
  type      = string
  sensitive = true
}
variable "github_email" { type = string }

variable "google_client_id" {
  type    = string
  default = ""
}
variable "google_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}
variable "facebook_client_id" {
  type    = string
  default = ""
}
variable "facebook_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}
variable "stripe_secret_key" {
  type      = string
  sensitive = true
  default   = ""
}
variable "stripe_public_key" {
  type    = string
  default = ""
}
