variable "resource_group_name" {
  type = string
}

variable "node_resource_group" {
  type = string
}

variable "kubelet_object_id" {
  type = string
}

variable "kubelet_client_id" {
  type = string
}

variable "ingress_ip" {
  type = string
}

variable "allowlist_cidr" {
  type = string
}

variable "dns_zone_id" {
  type = string
}

variable "dns_zone_name" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "letsencrypt_email" {
  type = string
}

variable "acme_staging" {
  type    = bool
  default = false
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
