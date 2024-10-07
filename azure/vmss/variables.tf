variable "resource_group_name" {
    type        = string
    default     = null
}
variable "location" {
    type        = string
    default     = null
}
variable "mockten_pri_subnet1" {
    type        = string
    default     = null
}

variable "vmss_sku" {
  description = "The SKU of the Virtual Machine Scale Set."
  type        = string
  default     = null
}

variable "vmss_tier" {
  description = "The Tier of the Virtual Machine Scale Set."
  type        = string
  default     = null
}

variable "vmss_capacity" {
  description = "The number of instances in the VM scale set."
  type        = string
  default     = null
}

variable "admin_username" {
  description = "The admin username for the VM."
  type        = string
  default     = null
}

variable "admin_password" {
  description = "The admin password for the VM."
  type        = string
  default     = null
}

variable "data_disk_size_gb" {
  description = "The size of the data disk in GB."
  type        = number
  default     = null
}

variable "managed_disk_type" {
  description = "The type of the managed disk (e.g., StandardSSD_LRS, Premium_LRS)."
  type        = string
  default    = null
}

variable "os_image_publisher" {
  description = "The publisher of the OS image."
  type        = string
  default     = null
}

variable "os_image_offer" {
  description = "The offer of the OS image."
  type        = string
  default     = null
}

variable "os_image_sku" {
  description = "The SKU of the OS image."
  type        = string
  default     = null
}

variable "os_image_version" {
  description = "The version of the OS image."
  type        = string
  default     = null
}

variable "mockten_bastion_subnet" {
  description = "Subnet ID of Azure Bastion"
  type        = string
  default     = null
}
