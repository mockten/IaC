variable "root_domain" {
  type = string
}

variable "ingress_ip" {
  type = string
}

variable "domain_api_base_url" {
  type = string
}

variable "domain_api_key" {
  type      = string
  sensitive = true
}

variable "enable_ns_push" {
  description = "Push the Cloud DNS nameservers to the registrar via its API so delegation needs no manual step."
  type        = bool
  default     = true
}

variable "domain_api_user_agent" {
  description = "User-Agent for the registrar API. Required: its WAF serves a Cloudflare challenge page to default client user-agents, which breaks the call."
  type        = string
  default     = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}
