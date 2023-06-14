### varialbe param(Common)
variable "project" {
    default =  "PROJECT_ID"
}
variable "location" {
    default =  "us-east1-b"
}
variable "credentials" {
    default =  "./account.json"
}

### varialbe param(Disk)
variable "mockten_disk_zone" {
    default = "us-east1-b"
}
variable "mockten_mysql_disk_size" {
    default =  20
}
variable "mockten_redis_disk_size" {
    default = 30
}
variable "dev_mysql_disk_size" {
    default = 20
}
variable "dev_redis_disk_size" {
    default = 30
}

### varialbe param(Dns) Please insert the preferred domain for you.
variable "dns_name" {
    default = "mockten.net."
}
variable "prd_mockten_dns_name" {
    default = "www.mockten.net."
}
variable "prd_prometheus_dns_name" {
    default = "www.prometheus.mockten.net."
}
variable "prd_grafana_dns_name" {
    default = "www.monitoring.mockten.net."
}
variable "dev_mockten_dns_name" {
    default = "www.dev.mockten.net."
}
variable "dev_prometheus_dns_name" {
    default = "www.devprometheus.mockten.net."
}
variable "dev_grafana_dns_name" {
    default = "www.devmonitoring.mockten.net."
}
variable "kiali_dns_name" {
    default = "www.kiali.mockten.net."
}


### varialbe param(k8s)
variable "k8s_location" {
    default = "us-east1"
}
variable "vpc_region" {
    default = "us-east1"
}