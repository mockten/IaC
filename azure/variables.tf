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

# ── AKS infrastructure knobs (consumed by the root main.tf) ──────────────────
variable "az_location" {
  # eastus frequently returns AKSCapacityHeavyUsage (region at capacity for new
  # clusters). All regions share the same tiny trial vCPU quota (4), so moving is
  # free — pick one that can currently create a cluster. The tfstate backend stays
  # in eastus regardless (backend region need not match the resources').
  description = "Azure region for the cluster and its resource group."
  type        = string
  default     = "eastus2"
}

variable "az_resource_group" {
  type    = string
  default = "mockten-rg"
}

variable "az_cluster_name" {
  type    = string
  default = "mockten-aks"
}

variable "az_kubernetes_version" {
  # Must be a GA (KubernetesOfficial) minor, not LTS-only — the "1.31" alias now
  # resolves to an LTS-only patch (K8sVersionNotSupported on a Free/Standard
  # cluster). Check: az aks get-versions --location <loc>
  #   --query "values[?contains(capabilities.supportPlan, 'KubernetesOfficial')].version".
  description = "Pinned AKS minor version. Must be a GA (non-LTS) version supported in az_location."
  type        = string
  default     = "1.34"
}

variable "az_storage_class" {
  description = "managed-csi is the default AKS class and binds WaitForFirstConsumer, which is what the minio and mysql PVCs need."
  type        = string
  default     = "managed-csi"
}
