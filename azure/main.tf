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
  subscription_id = "aeff0ece-6773-403f-8ddc-ad0b0f4dd179"
}
