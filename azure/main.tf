terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    resource_group_name   = "mockten-rg"
    storage_account_name  = "mocktenstorageaccount"
    container_name        = "mocktencontainer"
    key                   = "terraform.tfstate" 
  }
}

provider "azurerm" {
  features {}
  alias   = "azure"
}

module "nw" {
  source        = "./nw"
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_cidr           = var.vnet_cidr
  mockten_pub_subnet1_cidr   = var.mockten_pub_subnet1_cidr
  mockten_pub_subnet2_cidr   = var.mockten_pub_subnet2_cidr
  mockten_pri_subnet1_cidr   = var.mockten_pri_subnet1_cidr
  mockten_pri_subnet2_cidr   = var.mockten_pri_subnet2_cidr
  nsg_id              = module.fw.nsg_id

  providers = {
    azurerm = azurerm.azure
  }
}

module "fw" {
  source        = "./fw"
  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_cidr           = var.vnet_cidr

  providers = {
    azurerm = azurerm.azure
  }
}

module "vmss" {
  source        = "./vmss"
  resource_group_name = var.resource_group_name
  location            = var.location
  mockten_pri_subnet1 = module.nw.mockten_pri_subnet1
  vmss_sku            = var.vmss_sku
  vmss_tier           = var.vmss_tier
  vmss_capacity       = var.vmss_capacity
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  data_disk_size_gb   = var.data_disk_size_gb
  managed_disk_type   = var.managed_disk_type
  os_image_publisher  = var.os_image_publisher
  os_image_offer      = var.os_image_offer
  os_image_sku        = var.os_image_sku
  os_image_version    = var.os_image_version

  providers = {
    azurerm = azurerm.azure
  }
}
