resource "azurerm_virtual_machine_scale_set" "mockten_vmss" {
  name                = "mockten-vmss"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku {
    name     = "Standard_B2ats_v2"
    tier     = "Standard"
    capacity = 1
  }
  
  upgrade_policy_mode = "Manual"

  network_profile {
    name    = "mockten-network-profile"
    primary = true
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = var.mockten_pri_subnet1
    }
  }

  os_profile {
    computer_name_prefix = "vmss"
    admin_username       = "azureuser"
    admin_password       = "P@ssw0rd1234!"
  }

  storage_profile_os_disk {
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
