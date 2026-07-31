variable "cluster_name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "subnet_id" {
  type = string
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

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v7"
}
