# Root wiring for mockten on AKS — the Azure counterpart to gcp/main.tf. Each
# concern is a module (nw / aks / dns / platform), all consuming the same
# common/k8s workloads module GKE deploys.

data "azurerm_client_config" "current" {}

locals {
  host_store     = var.root_domain
  host_sales     = "sales.${var.root_domain}"
  host_admin     = "admin.${var.root_domain}"
  host_dashboard = "dashboard.${var.root_domain}"

  public_origins = [
    "https://${local.host_store}",
    "https://${local.host_sales}",
    "https://${local.host_admin}",
    "https://${local.host_dashboard}",
  ]
}

resource "random_password" "dashboard_session" {
  length  = 48
  special = false
}
resource "random_password" "e2e_admin" {
  length  = 32
  special = false
}
resource "random_password" "kc_admin" {
  length  = 32
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = var.az_resource_group
  location = var.az_location
}

module "nw" {
  source              = "./nw"
  name_prefix         = "mockten"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

module "aks" {
  source                  = "./aks"
  cluster_name            = var.az_cluster_name
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  kubernetes_version      = var.az_kubernetes_version
  subnet_id               = module.nw.subnet_id
  allowlist_cidr          = var.allowlist_cidr
  master_authorized_extra = var.master_authorized_extra
}

# Reserved up front so the DNS records and the LB agree at plan time. Must live in
# the AKS-managed node resource group, or the LB cannot claim it.
resource "azurerm_public_ip" "ingress" {
  name                = "mockten-ingress-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = module.aks.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

module "dns" {
  source                = "./dns"
  root_domain           = var.root_domain
  resource_group_name   = azurerm_resource_group.main.name
  ingress_ip            = azurerm_public_ip.ingress.ip_address
  domain_api_base_url   = var.domain_api_base_url
  domain_api_key        = var.domain_api_key
  domain_api_user_agent = var.domain_api_user_agent
  enable_ns_push        = var.enable_ns_push
}

module "platform" {
  source              = "./platform"
  resource_group_name = azurerm_resource_group.main.name
  node_resource_group = module.aks.node_resource_group
  kubelet_object_id   = module.aks.kubelet_object_id
  kubelet_client_id   = module.aks.kubelet_client_id
  ingress_ip          = azurerm_public_ip.ingress.ip_address
  allowlist_cidr      = var.allowlist_cidr
  dns_zone_id         = module.dns.zone_id
  dns_zone_name       = module.dns.zone_name
  subscription_id     = data.azurerm_client_config.current.subscription_id
  letsencrypt_email   = var.letsencrypt_email
  acme_staging        = var.acme_staging
  host_store          = local.host_store
  host_sales          = local.host_sales
  host_admin          = local.host_admin
  host_dashboard      = local.host_dashboard
}

# The portable workloads — the same module GKE deploys.
module "common_k8s" {
  source                 = "../common/k8s"
  github_username        = var.github_username
  github_token           = var.github_token
  github_email           = var.github_email
  google_client_id       = var.google_client_id
  google_client_secret   = var.google_client_secret
  facebook_client_id     = var.facebook_client_id
  facebook_client_secret = var.facebook_client_secret
  stripe_secret_key      = var.stripe_secret_key
  stripe_public_key      = var.stripe_public_key

  storage_class          = var.az_storage_class
  namespace_memory_quota = var.namespace_memory_quota
  kc_hostname            = local.host_store

  # See the note in gcp/main.tf: "true" is the value known to work, because the
  # uam image selects the realm from MOCKTEN_MODE before it looks at DEV_MODE.
  kc_dev_mode    = "true"
  public_origins = local.public_origins

  mockten_mode       = "cloud"
  public_base_domain = var.root_domain

  dashboard_session_secret_enabled = true
  dashboard_session_secret         = random_password.dashboard_session.result

  kc_admin_password  = random_password.kc_admin.result
  e2e_admin_enabled  = true
  e2e_admin_user     = "e2e-admin@${var.root_domain}"
  e2e_admin_password = random_password.e2e_admin.result

  # Parity with GCP so the dashboard reads all-READY on first open: seed purchase
  # data + train the model, and let the dashboard reach the ingress in-cluster for
  # its readiness TLS check (avoids the external-LB hairpin that reads PENDING).
  enable_seed_job     = true
  internal_ingress_ip = module.platform.ingress_cluster_ip

  depends_on = [module.aks]
}
