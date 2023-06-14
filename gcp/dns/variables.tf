variable "dns_name" {
    type        = string
    default     = null
}

variable "prd_mockten_rrdatas" {
  type        = list(string)
  default     = []
}

variable "prd_mockten_dns_name" {
    type        = string
    default     = null
}

variable "prd_prometheus_rrdatas" {
  type        = list(string)
  default     = []
}

variable "prd_prometheus_dns_name" {
    type        = string
    default     = null
}

variable "prd_grafana_rrdatas" {
  type        = list(string)
  default     = []
}

variable "prd_grafana_dns_name" {
    type        = string
    default     = null
}

variable "dev_mockten_rrdatas" {
  type        = list(string)
  default     = []
}

variable "dev_mockten_dns_name" {
    default = "www.dev.mockten.net."
}

variable "dev_prometheus_rrdatas" {
  type        = list(string)
  default     = []
}

variable "dev_prometheus_dns_name" {
    default = "www.devprometheus.mockten.net."
}

variable "dev_grafana_rrdatas" {
  type        = list(string)
  default     = []
}

variable "dev_grafana_dns_name" {
    default = "www.devmonitoring.mockten.net."
}

variable "kiali_rrdatas" {
  type        = list(string)
  default     = []
}

variable "kiali_dns_name" {
    default = "www.kiali.mockten.net."
}