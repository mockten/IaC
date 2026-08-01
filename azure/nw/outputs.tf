output "subnet_id" {
  value = azurerm_subnet.nodes.id
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}
