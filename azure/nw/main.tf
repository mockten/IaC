# VNet for the AKS cluster — the Azure counterpart to gcp/nw and aws/nw.
#
# Two subnets: one for the AKS nodes, and a dedicated one for the Application
# Gateway (v2 requires its own subnet). Clients reach the gateway directly (Azure
# Front Door is forbidden on Free Trial), so the subnet NSG admits only the
# allowlisted client IP(s) on HTTP/HTTPS, and the App Gateway WAF enforces the same
# set at L7. The GatewayManager rule is mandatory or App Gateway v2 will not
# provision.
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "nodes" {
  name                 = "nodes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

resource "azurerm_network_security_group" "appgw" {
  name                = "${var.name_prefix}-appgw-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Mandatory for App Gateway v2 health/management, or provisioning fails.
  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  # Client traffic: only from the allowlisted IP(s), on HTTP (redirected) and HTTPS.
  # Clients reach the gateway directly (no Front Door on Free Trial), so this is the
  # real client IP — the same set the App Gateway WAF enforces at L7.
  security_rule {
    name                       = "AllowAllowlistWeb"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefixes    = [for c in split(",", var.allowlist_cidr) : trimspace(c)]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "DenyOtherInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}
