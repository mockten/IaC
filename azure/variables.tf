### varialbe param(Common)
variable "resource_group_name" {
  default = "mockten-rg"
}
variable "location" {
    default =  "westus"
}
variable "MOCKTEN_REPO_PAT" {
  type = string
  description = "GitHub Personal Access Token for Mockten repository"
  default     = null
}

### varialbe param(NW)
variable "vnet_cidr" {
  default = "10.0.0.0/16"
}
variable "mockten_pub_subnet1_cidr" {
    default = "10.0.1.0/24"
}
variable "mockten_pub_subnet2_cidr" {
    default = "10.0.2.0/24"
}
variable "mockten_pri_subnet1_cidr" {
    default = "10.0.3.0/24"
}
variable "mockten_pri_subnet2_cidr" {
    default = "10.0.4.0/24"
}

variable "mockten_bastion_subnet_cidr" {
    default = "10.0.5.0/24"
}

### varialbe param(vmss)
variable "vmss_sku" {
  description = "The SKU of the Virtual Machine Scale Set."
  default     = "Standard_B2ats_v2"
}

variable "vmss_tier" {
  description = "The Tier of the Virtual Machine Scale Set."
  type        = string
  default     = "Standard"
}

variable "vmss_capacity" {
  description = "The number of instances in the VM scale set."
  type        = number
  default     = 1  
}

variable "admin_username" {
  description = "The admin username for the VM."
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "The admin password for the VM."
  type        = string
  default     = "P@ssw0rd1234!"
}

variable "data_disk_size_gb" {
  description = "The size of the data disk in GB."
  type        = number
  default     = 64
}

variable "managed_disk_type" {
  description = "The type of the managed disk (e.g., StandardSSD_LRS, Premium_LRS)."
  type        = string
  default     = "StandardSSD_LRS"
}

variable "os_image_publisher" {
  description = "The publisher of the OS image."
  type        = string
  default     = "Canonical"
}

variable "os_image_offer" {
  description = "The offer of the OS image."
  type        = string
  default     = "UbuntuServer"
}

variable "os_image_sku" {
  description = "The SKU of the OS image."
  type        = string
  default     = "18.04-LTS"
}

variable "os_image_version" {
  description = "The version of the OS image."
  type        = string
  default     = "latest"
}

### varialbe param(Disk)
#variable "mockten_disk_zone" {
#    default = "us-east1-b"
#}
#variable "mockten_mysql_disk_size" {
#    default =  20
#}
#variable "mockten_redis_disk_size" {
#    default = 30
#}
#variable "mockten_static_file_disk_size" {
#    default = 5
#}
#variable "dev_mysql_disk_size" {
#    default = 20
#}
#variable "dev_redis_disk_size" {
#    default = 30
#}
#variable "dev_static_file_disk_size" {
#    default = 5
#}

### varialbe param(Dns) Please insert the preferred domain for you.
variable "dns_name" {
    default = "mockten.net."
}
#variable "prd_mockten_dns_name" {
#    default = "www.mockten.net."
#}
#variable "prd_prometheus_dns_name" {
#    default = "www.prometheus.mockten.net."
#}
#variable "prd_grafana_dns_name" {
#    default = "www.monitoring.mockten.net."
#}
#variable "dev_mockten_dns_name" {
#    default = "www.dev.mockten.net."
#}
#variable "dev_prometheus_dns_name" {
#    default = "www.devprometheus.mockten.net."
#}
#variable "dev_grafana_dns_name" {
#    default = "www.devmonitoring.mockten.net."
#}
#variable "kiali_dns_name" {
#    default = "www.kiali.mockten.net."
#}

### varialbe param(k8s)
#variable "k8s_location" {
#    default = "us-east1"
#}
#variable "k8s_cluster_cidr" {
#    default = "172.16.0.0/16"
#}
#variable "k8s_service_cidr" {
#    default = "172.31.0.0/16"
#}
#variable "k8s_master_cidr" {
#    default = "192.168.200.0/28"
#}
#variable "maintenance_start_time" {
#    default = "2023-06-14T17:00:00Z"
#}
#variable "maintenance_end_time" {
#    default = "2024-06-14T21:00:00Z"
#}
#variable "maintenance_recurrence" {
#    default = "FREQ=WEEKLY;BYDAY=FR,SA,SU"
#}
#variable "master_authorized_permit_cidr" {
#    default     = "192.0.2.127/32"
#}
