variable "resource_group_name" { type = string }
variable "dns_zone_id" { type = string }
variable "dns_zone_name" { type = string }
variable "kubelet_object_id" { type = string }
variable "kubelet_client_id" { type = string }
variable "subscription_id" { type = string }
variable "letsencrypt_email" { type = string }
variable "acme_staging" {
  type    = bool
  default = false
}
