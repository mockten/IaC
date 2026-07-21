output "name" {
  value = google_container_cluster.mockten.name
}

output "endpoint" {
  value = google_container_cluster.mockten.endpoint
}

output "ca_certificate" {
  value     = google_container_cluster.mockten.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "workload_identity_pool" {
  value = "${var.project}.svc.id.goog"
}

# Workloads must wait for the node pool, not just the control plane.
output "node_pool_id" {
  value = google_container_node_pool.primary.id
}
