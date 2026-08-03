variable "project" {
  type = string
}

variable "global_ip_name" {
  description = "Name of the reserved global external IP the gce Ingress binds the Application LB to."
  type        = string
}

variable "allowlist_cidr" {
  type = string
}

variable "egress_cidr" {
  description = "The cluster's Cloud NAT egress IP as a /32, allowlisted in Cloud Armor alongside allowlist_cidr so the dashboard's in-cluster HTTPS self-check (pod → public URL) is not blocked."
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
