variable "project" {
  type = string
}

variable "ingress_ip" {
  type = string
}

variable "allowlist_cidr" {
  type = string
}

variable "letsencrypt_email" {
  type = string
}

variable "workload_identity_pool" {
  type = string
}

variable "dns_zone_name" {
  description = "Cloud DNS managed-zone name the ACME DNS-01 solver writes challenge TXT records into."
  type        = string
}

variable "host_store" {
  type = string
}
variable "host_sales" {
  type = string
}
variable "host_admin" {
  type = string
}
variable "host_dashboard" {
  type = string
}

variable "acme_staging" {
  description = "Issue certificates from Let's Encrypt's staging CA. Untrusted by browsers, but effectively unmetered — use it while iterating so rebuilds do not burn the production limit of 5 certs per identifier set per 168h."
  type        = bool
  default     = false
}
