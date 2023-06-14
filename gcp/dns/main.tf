resource "google_dns_managed_zone" "mockten_zone" {
  name        = "mockten-zone"
  description = "mockten-zone"
  dns_name    = var.dns_name
}

resource "google_dns_record_set" "prd_mockten_record" {
  name    = var.prd_mockten_dns_name
  type    = "A"
  ttl     = 300
  managed_zone = google_dns_managed_zone.mockten_zone.name
  rrdatas = var.prd_mockten_rrdatas
}

resource "google_dns_record_set" "prd_prometheus_record" {
  name    = var.prd_prometheus_dns_name
  type    = "A"
  ttl     = 300
  managed_zone = google_dns_managed_zone.mockten_zone.name
  rrdatas = var.prd_prometheus_rrdatas
}

resource "google_dns_record_set" "prd_grafana_record" {
  name    = var.prd_grafana_dns_name
  type    = "A"
  ttl     = 300
  managed_zone = google_dns_managed_zone.mockten_zone.name
  rrdatas = var.prd_grafana_rrdatas
}

resource "google_dns_record_set" "dev_mockten_record" {
  name    = var.dev_mockten_dns_name
  type    = "A"
  ttl     = 300
  managed_zone = google_dns_managed_zone.mockten_zone.name
  rrdatas = var.dev_mockten_rrdatas
}

resource "google_dns_record_set" "dev_prometheus_record" {
  name    = var.dev_prometheus_dns_name
  type    = "A"
  ttl     = 300
  managed_zone = google_dns_managed_zone.mockten_zone.name
  rrdatas = var.dev_prometheus_rrdatas
}

resource "google_dns_record_set" "dev_grafana_record" {
  name    = var.dev_grafana_dns_name
  type    = "A"
  ttl     = 300
  managed_zone = google_dns_managed_zone.mockten_zone.name
  rrdatas = var.dev_grafana_rrdatas
}

resource "google_dns_record_set" "kiali_record" {
  name    = var.kiali_dns_name
  type    = "A"
  ttl     = 300
  managed_zone = google_dns_managed_zone.mockten_zone.name
  rrdatas = var.kiali_rrdatas
}