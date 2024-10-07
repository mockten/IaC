output "mockten_pri_subnet1" {
  value = azurerm_subnet.mockten_pri_subnet1.id
  description = "App Subnet ID"
}
output "mockten_bastion_subnet" {
  value = azurerm_subnet.mockten_bastion_subnet.id
  description = "Bastion Subnet ID"
}