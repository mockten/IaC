output "vpc_self_link" {
  description = "VPC Self Link"
  value       = google_compute_network.mockten_vpc.self_link
}

output "subnet_self_link" {
  description = "Subnet Self Link"
  value       = google_compute_subnetwork.mockten_subnet.self_link
}