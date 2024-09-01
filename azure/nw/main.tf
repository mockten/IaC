# Virtual Network
resource "azurerm_virtual_network" "mockten_vnet" {
  name                = "mockten-vnet"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Subnet
resource "azurerm_subnet" "mockten_pub_subnet1_cidr" {
  name                 = "mockten-subnet-public1"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mockten_vnet.name
  address_prefixes     = [var.pub_subnet_a_cidr]
}