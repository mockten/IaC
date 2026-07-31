resource "azurerm_network_security_group" "mockten_app_nsg" {
  name                = "mockten-app-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location

  security_rule {
    name                       = "allow_http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = var.vnet_cidr
  }

  security_rule {
    name                       = "allow_https"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = var.vnet_cidr
  }
}
