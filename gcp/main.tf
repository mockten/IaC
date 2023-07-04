provider "google" {
  project = var.project
  region  = var.location
  credentials = var.credentials
}

terraform {
  backend "gcs" {
    bucket = "PROJECT_ID-bucket"
    prefix = "terraform/state"
  }
}

resource "google_compute_global_address" "prd_grafana_ip" {
  name = "prd-grafana-ip"
}

resource "google_compute_global_address" "prd_prometheus_ip" {
  name = "prd-prometheus-ip"
}

resource "google_compute_global_address" "prd_mockten_ip" {
  name = "prd-mockten-ip"
}

resource "google_compute_global_address" "dev_grafana_ip" {
  name = "dev-grafana-ip"
}

resource "google_compute_global_address" "dev_prometheus_ip" {
  name = "dev-prometheus-ip"
}

resource "google_compute_global_address" "dev_mockten_ip" {
  name = "dev-mockten-ip"
}

resource "google_compute_global_address" "dev_kiali_ip" {
  name = "dev-kiali-ip"
}

module "disk" {
  source = "./disk"
  mockten_disk_zone       = var.mockten_disk_zone
  mockten_mysql_disk_size = var.mockten_mysql_disk_size
  mockten_redis_disk_size = var.mockten_redis_disk_size
  dev_mysql_disk_size     = var.dev_mysql_disk_size
  dev_redis_disk_size     = var.dev_redis_disk_size
}

module "dns" {
  source                  = "./dns"
  dns_name                = var.dns_name
  prd_mockten_rrdatas     = [google_compute_global_address.prd_mockten_ip.address]
  prd_mockten_dns_name    = var.prd_mockten_dns_name
  prd_prometheus_rrdatas  = [google_compute_global_address.prd_prometheus_ip.address]
  prd_prometheus_dns_name = var.prd_prometheus_dns_name
  prd_grafana_rrdatas     = [google_compute_global_address.prd_grafana_ip.address]
  prd_grafana_dns_name    = var.prd_grafana_dns_name
  dev_mockten_rrdatas     = [google_compute_global_address.dev_mockten_ip.address]
  dev_mockten_dns_name    = var.dev_mockten_dns_name
  dev_prometheus_rrdatas  = [google_compute_global_address.dev_prometheus_ip.address]
  dev_prometheus_dns_name = var.dev_prometheus_dns_name
  dev_grafana_rrdatas     = [google_compute_global_address.dev_grafana_ip.address]
  dev_grafana_dns_name    = var.dev_grafana_dns_name
  kiali_rrdatas           = [google_compute_global_address.dev_kiali_ip.address]
  kiali_dns_name          = var.kiali_dns_name
}

module "nw" {
  source        = "./nw"
  ip_cidr_range = var.ip_cidr_range
  vpc_region    = var.vpc_region
}

module "k8s" {
  source                        = "./k8s"
  k8s_location                  = var.k8s_location
  k8s_cluster_cidr              = var.k8s_cluster_cidr
  k8s_master_cidr               = var.k8s_master_cidr
  maintenance_start_time        = var.maintenance_start_time
  maintenance_end_time          = var.maintenance_end_time
  maintenance_recurrence        = var.maintenance_recurrence
  master_authorized_permit_cidr = var.master_authorized_permit_cidr
  vpc_self_link                 = module.nw.vpc_self_link
  subnet_self_link              = module.nw.subnet_self_link
}