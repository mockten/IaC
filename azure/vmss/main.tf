resource "azurerm_virtual_machine_scale_set" "mockten_vmss" {
  name                = "mockten-vmss"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku {
    name     = var.vmss_sku
    tier     = var.vmss_tier
    capacity = var.vmss_capacity
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
    admin_username       = var.admin_username
    admin_password       = var.admin_password
  }

  storage_profile_os_disk {
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "StandardSSD_LRS"
  }

  storage_profile_data_disk {
    lun               = 0
    caching           = "ReadWrite"
    create_option     = "Empty"
    disk_size_gb      = var.data_disk_size_gb
    managed_disk_type = var.managed_disk_type
  }

  storage_profile_image_reference {
    publisher = var.os_image_publisher
    offer     = var.os_image_offer
    sku       = var.os_image_sku
    version   = var.os_image_version
  }
}
