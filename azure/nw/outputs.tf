output "subnet_id" {
  value = azurerm_subnet.nodes.id
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "aks_egress_ip_id" {
  value = azurerm_public_ip.aks_egress.id
}

output "aks_egress_ip" {
  value = azurerm_public_ip.aks_egress.ip_address
}
