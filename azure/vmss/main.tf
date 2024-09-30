resource "azurerm_kubernetes_cluster" "mockten_aks" {
  name                = "mockten-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "mockten"

  default_node_pool {
    name                = "default"
    node_count          = var.vmss_capacity  
    vm_size             = var.vmss_sku       
    vnet_subnet_id      = var.mockten_pri_subnet1
    os_disk_size_gb     = var.data_disk_size_gb
    enable_auto_scaling = false
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
  }

  tags = {
    environment = "development" 
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "extra_node_pool" {
  depends_on          = [azurerm_kubernetes_cluster.mockten_aks]
  kubernetes_cluster_id = azurerm_kubernetes_cluster.mockten_aks.id

  name                = "mocktenpool"
  node_count          = var.vmss_capacity
  vm_size             = var.vmss_sku  
  vnet_subnet_id      = var.mockten_pri_subnet1
  os_disk_size_gb     = var.data_disk_size_gb
  enable_auto_scaling = false
  node_labels = {
    environment = "development"  
  }

  tags = {
    environment = "development"  
  }
}

