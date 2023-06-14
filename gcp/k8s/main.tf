resource "google_container_cluster" "mockten_k8s_cluster" {
  name     = "mockten-k8s-cluster"

  enable_autopilot = true
  location = var.k8s_location

  release_channel {
    channel = "STABLE"
  }

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.28.0.0/14"
  }

  network    = google_compute_network.mockten_vpc.self_link
  subnetwork = google_compute_subnetwork.mockten_subnet.self_link

  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = true
    master_ipv4_cidr_block = "192.168.100.0/28"

    master_global_access_config {
    enabled = false
    }
  }

  master_authorized_networks_config {
  }

  maintenance_policy {
    recurring_window {
      start_time = "2023-06-14T17:00:00Z"
      end_time   = "2023-06-14T21:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=FR,SA,SU"
    }
  }
}

# VPC
resource "google_compute_network" "mockten_vpc" {
  name                    = "mockten-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Subnet
resource "google_compute_subnetwork" "mockten_subnet" {
  name          = "mockten-subnet-private1"
  ip_cidr_range = "192.168.1.0/24"
  region        = var.vpc_region
  network       = google_compute_network.mockten_vpc.id
}