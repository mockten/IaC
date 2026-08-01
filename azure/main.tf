# Root wiring for mockten on AKS — cloud-native, mirroring aws/. Unlike gcp/ (and
# the old azure/ that used ingress-nginx + cert-manager), Azure here is
# vendor-native: AGIC + Application Gateway (WAF) for ingress, Azure Front Door
# (Standard) in front for edge caching and managed TLS. Module order matters:
#   nw -> appgw -> aks(AGIC) -> AGIC role assignments -> common_k8s -> routing,
# with dns + cdn (Front Door owns the DNS records) alongside.

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
  allowlist_cidr      = var.allowlist_cidr
}

# Application Gateway must exist before the cluster's AGIC add-on can reference it.
module "appgw" {
  source              = "./appgw"
  name_prefix         = "mockten"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  appgw_subnet_id     = module.nw.appgw_subnet_id
  allowlist_cidr      = var.allowlist_cidr
  aks_egress_ip       = module.nw.aks_egress_ip
}

module "aks" {
  source                  = "./aks"
  cluster_name            = var.az_cluster_name
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  kubernetes_version      = var.az_kubernetes_version
  subnet_id               = module.nw.subnet_id
  appgw_id                = module.appgw.id
  aks_egress_ip_id        = module.nw.aks_egress_ip_id
  allowlist_cidr          = var.allowlist_cidr
  master_authorized_extra = var.master_authorized_extra
}

# AGIC's managed identity needs to program the gateway and read the RG.
resource "azurerm_role_assignment" "agic_appgw" {
  scope                = module.appgw.id
  role_definition_name = "Contributor"
  principal_id         = module.aks.agic_identity_object_id
}
resource "azurerm_role_assignment" "agic_rg_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = module.aks.agic_identity_object_id
}

module "dns" {
  source                = "./dns"
  root_domain           = var.root_domain
  resource_group_name   = azurerm_resource_group.main.name
  appgw_ip              = module.appgw.public_ip
  domain_api_base_url   = var.domain_api_base_url
  domain_api_key        = var.domain_api_key
  domain_api_user_agent = var.domain_api_user_agent
  enable_ns_push        = var.enable_ns_push
}

# TLS for the AGIC/App Gateway ingress: cert-manager issues Let's Encrypt certs via
# a DNS-01 solver against the zone (Front Door's managed certs are unavailable on
# Free Trial). AGIC serves the issued secrets on the gateway's HTTPS listener.
module "platform" {
  source              = "./platform"
  resource_group_name = azurerm_resource_group.main.name
  dns_zone_id         = module.dns.zone_id
  dns_zone_name       = module.dns.zone_name
  kubelet_object_id   = module.aks.kubelet_object_id
  kubelet_client_id   = module.aks.kubelet_client_id
  subscription_id     = data.azurerm_client_config.current.subscription_id
  letsencrypt_email   = var.letsencrypt_email
  acme_staging        = var.acme_staging
}

# The portable workloads — the same module GKE/EKS deploy.
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

  # Seed purchase data + train the model so the dashboard reads all-READY. Like
  # aws/, there is no internal_ingress_ip hostAlias: the App Gateway is external
  # (no in-cluster ClusterIP), so the dashboard reaches its readiness endpoint the
  # normal way.
  enable_seed_job = true

  depends_on = [module.aks]
}

# The Ingresses AGIC programs onto the gateway. Last: the backend Services must
# exist, and AGIC must already hold its role assignments.
module "routing" {
  source         = "./routing"
  host_store     = local.host_store
  host_sales     = local.host_sales
  host_admin     = local.host_admin
  host_dashboard = local.host_dashboard

  depends_on = [module.common_k8s, module.platform, azurerm_role_assignment.agic_appgw]
}
