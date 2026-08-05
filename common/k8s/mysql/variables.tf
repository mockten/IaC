variable "secret_name" {
  description = "The name of the Kubernetes secret for image pull"
  type        = string
}

variable "storage_class" {
  description = "StorageClass for the MySQL PVC. docker-desktop uses hostpath; GKE uses standard-rwo."
  type        = string
  default     = "hostpath"
}
variable "image_tag" {
  description = "Image tag to deploy for this service (e.g. \"1.64\" or \"latest\")."
  type        = string
  default     = "latest"
}
