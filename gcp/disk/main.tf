resource "google_compute_disk" "mockten_mysql_disk" {
  name = "mockten-mysql-disk"
  zone = var.mockten_disk_zone
  size = var.mockten_mysql_disk_size
  type = "pd-standard"
}

resource "google_compute_disk" "mockten_redis_disk" {
  name = "mockten-redis-disk"
  zone = var.mockten_disk_zone
  size = var.mockten_redis_disk_size
  type = "pd-standard"
}

resource "google_compute_disk" "mockten_static_file_disk" {
  name = "mockten-static-file-disk"
  zone = var.mockten_disk_zone
  size = var.mockten_static_file_disk_size
  type = "pd-standard"
}


resource "google_compute_disk" "dev_mysql_disk" {
  name = "dev-mysql-disk"
  zone = var.mockten_disk_zone
  size = var.dev_mysql_disk_size
  type = "pd-standard"
}

resource "google_compute_disk" "dev_redis_disk" {
  name = "dev-redis-disk"
  zone = var.mockten_disk_zone
  size = var.dev_redis_disk_size
  type = "pd-standard"
}

resource "google_compute_disk" "dev_static_file_disk" {
  name = "dev-static-file-disk"
  zone = var.mockten_disk_zone
  size = var.dev_static_file_disk_size
  type = "pd-standard"
}