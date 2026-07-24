# ClusterIP of the ingress-nginx controller, read back after the chart installs.
# The dashboard uses it to resolve the public hostnames in-cluster (hostAliases)
# so its readiness HTTPS self-check terminates TLS against the ingress directly
# instead of hairpinning to the external load-balancer IP.
data "kubernetes_service" "ingress_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.ingress_nginx]
}

output "ingress_cluster_ip" {
  value = data.kubernetes_service.ingress_controller.spec[0].cluster_ip
}
