# VPC
resource "google_compute_network" "mockten_vpc" {
  name                    = "mockten-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Subnet
resource "google_compute_subnetwork" "mockten_subnet" {
  name                     = "mockten-subnet-private1"
  ip_cidr_range            = var.ip_cidr_range
  region                   = var.vpc_region
  network                  = google_compute_network.mockten_vpc.id
  private_ip_google_access = true
}