variable "k8s_location" {
    type        = string
    default     = null
}
variable "vpc_self_link" {
    type        = string
    default     = null
}
variable "subnet_self_link" {
    type        = string
    default     = null
}
variable "k8s_cluster_cidr" {
    type        = string
    default     = null
}
variable "k8s_service_cidr" {
    type        = string
    default     = null
}
variable "k8s_master_cidr" {
    type        = string
    default     = null
}
variable "maintenance_start_time" {
    type        = string
    default     = null
}
variable "maintenance_end_time" {
    type        = string
    default     = null
}
variable "maintenance_recurrence" {
    type        = string
    default     = null
}

variable "master_authorized_permit_cidr" {
    type        = string
    default     = null
}