variable "root_domain" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "domain_api_base_url" {
  type = string
}

variable "domain_api_key" {
  type      = string
  sensitive = true
}

variable "domain_api_user_agent" {
  type = string
}

variable "enable_ns_push" {
  type    = bool
  default = true
}
