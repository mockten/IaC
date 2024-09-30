resource "azurerm_kubernetes_cluster" "mockten_aks" {
  name                = "mockten-aks"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = "mockten"

  default_node_pool {
    name                = "mocktenPool"
    node_count          = var.vmss_capacity  
    vm_size             = var.vmss_sku       
    vnet_subnet_id      = var.mockten_pri_subnet1
    os_disk_size_gb     = var.data_disk_size_gb
    enable_auto_scaling = false
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "development" 
  }
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.mockten_aks.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.mockten_aks.kube_config_raw

  sensitive = true
}

