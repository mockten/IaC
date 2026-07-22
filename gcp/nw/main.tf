# VPC-native networking for the GKE cluster.

resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.name_prefix}-subnet"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# Private GKE nodes have no external IPs, so without Cloud NAT they cannot reach
# the internet — every pod would fail to pull ghcr.io/mockten/* (ImagePullBackOff).
# The old gcp/ config had private nodes and no NAT; this is the fix.
resource "google_compute_router" "router" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Static egress IP for Cloud NAT. Reserved (not AUTO_ONLY) so the cluster's own
# egress address is stable and can be allowlisted on the ingress LB — otherwise
# the dashboard's HTTPS self-check (pod → public URL) is blocked by
# loadBalancerSourceRanges and the "Environment" panel reads PENDING forever.
resource "google_compute_address" "nat" {
  name   = "${var.name_prefix}-nat-ip"
  region = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.name_prefix}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
