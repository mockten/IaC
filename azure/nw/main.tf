# Virtual Network
resource "azurerm_virtual_network" "mockten_vnet" {
  name                = "mockten-vnet"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Subnet
resource "azurerm_subnet" "mockten_pub_subnet1" {
  name                 = "mockten-subnet-public1"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mockten_vnet.name
  address_prefixes     = [var.mockten_pub_subnet1_cidr]
}
resource "azurerm_subnet" "mockten_pub_subnet2" {
  name                 = "mockten-subnet-public2"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mockten_vnet.name
  address_prefixes     = [var.mockten_pub_subnet2_cidr]
}
resource "azurerm_subnet" "mockten_pri_subnet1" {
  name                 = "mockten-subnet-private1"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mockten_vnet.name
  address_prefixes     = [var.mockten_pri_subnet1_cidr]
}
resource "azurerm_subnet" "mockten_pri_subnet2" {
  name                 = "mockten-subnet-private2"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mockten_vnet.name
  address_prefixes     = [var.mockten_pri_subnet2_cidr]
}

resource "azurerm_subnet" "mockten_bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mockten_vnet.name
  address_prefixes     = [var.mockten_bastion_subnet_cidr]
}

resource "azurerm_subnet_network_security_group_association" "app-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.mockten_pri_subnet1.id
  network_security_group_id = var.nsg_id
}
