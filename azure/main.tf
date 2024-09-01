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
  providers = {
    azurerm = azurerm.azure
  }
}