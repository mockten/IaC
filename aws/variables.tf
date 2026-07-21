# Same contract as gcp/variables.tf: anything operator-specific has NO default,
# so it must arrive through TF_VAR_* (.env locally, GitHub secrets in CI) and can
# never be committed. Terraform fails fast if one is missing.

variable "region" {
  description = "AWS region for the VPC, EKS cluster and NAT"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "mockten-eks"
}

variable "kubernetes_version" {
  description = "EKS control plane version. Pinned: an unpinned version silently upgrades on re-apply."
  type        = string
  default     = "1.31"
}

# ── Access control ───────────────────────────────────────────────────────────
variable "allowlist_cidr" {
  description = "The one CIDR allowed to reach the HTTPS ingress AND the EKS API server (your home/office IP). TF_VAR_allowlist_cidr ← ALLOWLIST_CIDR."
  type        = string
}

variable "master_authorized_extra" {
  description = "Extra CIDRs for the API server only (e.g. the GitHub Actions runner's egress IP, injected per-run). Never opened on the ingress."
  type        = list(string)
  default     = []
}

# ── Domain / DNS delegation ──────────────────────────────────────────────────
variable "root_domain" {
  description = "Apex domain served by the storefront, no trailing dot. TF_VAR_root_domain ← ROOT_DOMAIN."
  type        = string
}

variable "letsencrypt_email" {
  description = "ACME account email for Let's Encrypt expiry notices."
  type        = string
}

variable "domain_api_base_url" {
  description = "DigitalPlat domain API base. Nameserver push targets {base}/domains/{domain}/nameservers."
  type        = string
  default     = "https://domain-api.digitalplat.org/api/v1"
}

variable "domain_api_key" {
  description = "DigitalPlat API bearer token (dp_live_...)."
  type        = string
  sensitive   = true
}

variable "domain_api_user_agent" {
  description = "The registrar's WAF rejects non-browser agents outright, which looks like an auth failure. Send a browser UA."
  type        = string
  default     = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
}

variable "enable_ns_push" {
  description = "Push the Route53 nameservers to the registrar automatically."
  type        = bool
  default     = true
}

variable "acme_staging" {
  description = "Issue from Let's Encrypt staging. Production allows only 5 certificates per identifier set per 168h, and a stack that rebuilds whole burns that fast."
  type        = bool
  default     = false
}

# ── Platform knobs passed into common/k8s ────────────────────────────────────
variable "storage_class" {
  description = "StorageClass for stateful PVCs. gp3 comes from the EBS CSI addon (see eks/)."
  type        = string
  default     = "gp3"
}

variable "namespace_memory_quota" {
  description = "Namespace memory budget; the dashboard's Total Memory denominator."
  type        = string
  default     = "16Gi"
}

# ── Application secrets / creds (same set as gcp, via TF_VAR_*) ───────────────
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

# ── Derived hostnames (identical split to gcp) ───────────────────────────────
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
