output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

output "kubelet_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "kubelet_client_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].client_id
}

# kube_config fields, used to configure the kubernetes/helm/kubectl providers at
# the root. Sensitive so they are not printed in plan output.
output "kube_host" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive = true
}

output "kube_client_certificate" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].client_certificate
  sensitive = true
}

output "kube_client_key" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].client_key
  sensitive = true
}

output "kube_cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive = true
}
