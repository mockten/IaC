output "mockten_vnet" {
  value = azurerm_virtual_network.mockten_vnet.id
  description = "Mockten Vnet ID"
}
output "mockten_pri_subnet1" {
  value = azurerm_subnet.mockten_pri_subnet1.id
  description = "App Subnet ID"
}