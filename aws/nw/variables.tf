variable "region" { type = string }
variable "cluster_name" { type = string }

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}
