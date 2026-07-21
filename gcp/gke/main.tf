# GKE Standard (zonal), not Autopilot. Autopilot injects a 0.5 vCPU / 2 GiB
# request into every pod that doesn't declare one — for mockten's ~21 tiny
# services that balloons to ~10 vCPU / ~42 GiB and blows past both the namespace
# ResourceQuota and a fresh project's GCE quota, so nothing schedules. Standard
# runs the pods best-effort and packs them onto a small node pool, exactly like
# the local single-node cluster. GKE still ships metrics-server managed, so the
# dashboard's CPU/Memory works.

resource "google_container_cluster" "mockten" {
  name     = var.cluster_name
  location = var.zone # zonal: nodes live in one zone, mirroring local's single node

  # Own node pool below, so drop the default one.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_self_link
  subnetwork = var.subnet_self_link

  # Must be false or `terraform destroy` (the teardown step) is blocked.
  deletion_protection = false

  release_channel {
    channel = "STABLE"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = toset(concat([var.allowlist_cidr], var.master_authorized_extra))
      content {
        cidr_block = cidr_blocks.value
      }
    }
  }

  # Standard doesn't enable Workload Identity by default; cert-manager's DNS-01
  # solver needs it.
  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }
}

resource "google_container_node_pool" "primary" {
  name       = "primary"
  cluster    = google_container_cluster.mockten.id
  location   = var.zone
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    disk_type    = "pd-balanced"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    # Needed for Workload Identity on the nodes.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
