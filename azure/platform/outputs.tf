output "ingress_cluster_ip" {
  value = data.kubernetes_service.ingress_controller.spec[0].cluster_ip
}
