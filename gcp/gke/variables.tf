variable "project" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "zone" {
  type = string
}

variable "network_self_link" {
  type = string
}

variable "subnet_self_link" {
  type = string
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "master_cidr" {
  type    = string
  default = "172.16.0.0/28"
}

variable "allowlist_cidr" {
  type = string
}

variable "master_authorized_extra" {
  type    = list(string)
  default = []
}

variable "node_count" {
  type    = number
  default = 2
}

variable "machine_type" {
  type    = string
  default = "e2-standard-4"
}
