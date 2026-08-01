variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "appgw_subnet_id" { type = string }
variable "allowlist_cidr" { type = string }
# The cluster's static egress IP (from ../nw). Allowlisted at the WAF too, so the
# dashboard's in-cluster self-probe of the public HTTPS endpoint is not blocked.
variable "aks_egress_ip" { type = string }
