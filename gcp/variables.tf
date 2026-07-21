# ── GCP project / location ───────────────────────────────────────────────────
# Values that differ per operator (project, domain, home IP, email) have NO
# default on purpose: they must come from TF_VAR_* (.env locally, GitHub secrets
# in CI) so nobody's project id, domain or home IP is ever committed. Terraform
# fails fast if one is missing.
variable "project" {
  description = "GCP project ID (TF_VAR_project ← GCP_PROJECT)"
  type        = string
}

variable "region" {
  description = "Region for the ingress LB IP, the subnet, and Cloud NAT"
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "Zone for the (zonal) GKE Standard cluster and its node pool"
  type        = string
  default     = "us-east1-b"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "mockten-gke"
}

# ── Access control ───────────────────────────────────────────────────────────
variable "allowlist_cidr" {
  description = "The one CIDR allowed to reach the HTTPS ingress AND the GKE control plane (your home/office IP). TF_VAR_allowlist_cidr ← ALLOWLIST_CIDR."
  type        = string
}

variable "master_authorized_extra" {
  description = "Extra CIDRs for the control plane only (e.g. the GitHub Actions runner's egress IP, injected per-run). Not opened on the ingress."
  type        = list(string)
  default     = []
}

# ── Domain / DNS delegation ──────────────────────────────────────────────────
variable "root_domain" {
  description = "Apex domain served by the storefront, no trailing dot (e.g. example.dpdns.org). TF_VAR_root_domain ← ROOT_DOMAIN. Whoever clones this repo brings their own domain; the same domain can be moved between clouds by tearing one down and applying the next."
  type        = string
}

variable "letsencrypt_email" {
  description = "ACME account email for Let's Encrypt expiry notices. TF_VAR_letsencrypt_email ← LETSENCRYPT_EMAIL."
  type        = string
}

variable "domain_api_base_url" {
  description = "DigitalPlat domain API base. Nameserver push targets {base}/domains/{domain}/nameservers."
  type        = string
  default     = "https://domain-api.digitalplat.org/api/v1"
}

variable "domain_api_key" {
  description = "DigitalPlat API bearer token (dp_live_...). Supplied via TF_VAR_domain_api_key from .env / GitHub secret."
  type        = string
  sensitive   = true
}

# ── Platform knobs passed into common/k8s ────────────────────────────────────
variable "storage_class" {
  description = "StorageClass for stateful PVCs on GKE."
  type        = string
  default     = "standard-rwo"
}

variable "namespace_memory_quota" {
  description = "Namespace memory budget; the dashboard's Total Memory denominator. Larger than local's 8Gi because Autopilot injects higher per-pod requests — too tight a quota would reject pods. Tuned against real usage during apply."
  type        = string
  default     = "16Gi"
}

# ── Application secrets / creds (same set as local, via TF_VAR_*) ─────────────
variable "github_username" {
  type = string
}
variable "github_token" {
  type      = string
  sensitive = true
}
variable "github_email" {
  type = string
}
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

# ── Derived hostnames ────────────────────────────────────────────────────────
locals {
  host_store     = var.root_domain
  host_sales     = "sales.${var.root_domain}"
  host_admin     = "admin.${var.root_domain}"
  host_dashboard = "dashboard.${var.root_domain}"

  public_origins = [
    "https://${local.host_store}",
    "https://${local.host_sales}",
    "https://${local.host_admin}",
    "https://${local.host_dashboard}",
  ]
}

variable "acme_staging" {
  description = "Use Let's Encrypt staging for TLS. Set true while iterating (rebuilds burn the production rate limit: 5 per identifier set per 168h), false for a demonstrable run. TF_VAR_acme_staging ← ACME_STAGING."
  type        = bool
  default     = false
}
