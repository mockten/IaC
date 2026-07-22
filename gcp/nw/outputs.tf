output "network_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnet_self_link" {
  value = google_compute_subnetwork.subnet.self_link
}

output "pods_range_name" {
  value = "pods"
}

output "services_range_name" {
  value = "services"
}

output "nat_ip" {
  value = google_compute_address.nat.address
}
