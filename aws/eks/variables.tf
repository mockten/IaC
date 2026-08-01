variable "cluster_name" { type = string }
variable "kubernetes_version" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "allowlist_cidr" { type = string }
variable "master_authorized_extra" { type = list(string) }
