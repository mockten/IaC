variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "vnet_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.40.0.0/20"
}
