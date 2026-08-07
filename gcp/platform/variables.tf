variable "project" {
  type = string
}

variable "ingress_ip" {
  type = string
}

variable "allowlist_cidr" {
  type = string
}

variable "egress_cidr" {
  description = "The cluster's Cloud NAT egress IP as a /32, allowlisted on the ingress LB alongside allowlist_cidr so in-cluster health checks (dashboard → public URL) aren't blocked by loadBalancerSourceRanges."
  type        = string
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

