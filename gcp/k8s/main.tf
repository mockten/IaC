resource "google_container_cluster" "mockten_k8s_cluster" {
  name     = "mockten-k8s-cluster"
  enable_autopilot = true
  location = var.k8s_location
  network    = var.vpc_self_link
  subnetwork = var.subnet_self_link
  
  release_channel {
    channel = "STABLE"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.k8s_cluster_cidr
    services_ipv4_cidr_block = var.k8s_service_cidr
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.k8s_master_cidr
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.master_authorized_permit_cidr
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }
}