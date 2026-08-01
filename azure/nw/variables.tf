variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "allowlist_cidr" {
  description = "CIDR(s) allowed to reach the App Gateway at L3, comma-separated."
  type        = string
}

variable "vnet_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.40.0.0/20"
}

variable "appgw_subnet_cidr" {
  type    = string
  default = "10.40.16.0/24"
}
