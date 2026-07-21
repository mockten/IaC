# DRAFT — mirrors gcp/main.tf. Never applied; no AWS account existed when this
# was written. (Replaces an 11-line provider stub; the provider block now lives
# in providers.tf, matching gcp's layout.)
#
# The ordering below is the part most likely to need adjusting. On GCP the LB IP
# is reserved up front so DNS and the platform can be built in parallel; an AWS
# load balancer only gets its hostname once the Service exists, so DNS records
# must wait for the platform module.

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

module "nw" {
  source       = "./nw"
  region       = var.region
  cluster_name = var.cluster_name
}

module "eks" {
  source                  = "./eks"
  cluster_name            = var.cluster_name
  kubernetes_version      = var.kubernetes_version
  private_subnet_ids      = module.nw.private_subnet_ids
  public_subnet_ids       = module.nw.public_subnet_ids
  allowlist_cidr          = var.allowlist_cidr
  master_authorized_extra = var.master_authorized_extra
  storage_class           = var.storage_class
}

# Canonical hosted zone id for ELB/NLB alias targets in this region.
data "aws_elb_hosted_zone_id" "this" {}

module "dns" {
  source                = "./dns"
  root_domain           = var.root_domain
  ingress_hostname      = module.platform.ingress_hostname
  ingress_zone_id       = data.aws_elb_hosted_zone_id.this.id
  domain_api_base_url   = var.domain_api_base_url
  domain_api_key        = var.domain_api_key
  domain_api_user_agent = var.domain_api_user_agent
  enable_ns_push        = var.enable_ns_push
}

module "platform" {
  source            = "./platform"
  region            = var.region
  allowlist_cidr    = var.allowlist_cidr
  letsencrypt_email = var.letsencrypt_email
  acme_staging      = var.acme_staging

  # KNOWN ISSUE, unresolved in this draft: cert-manager needs the zone id, and
  # the zone's records need the LB hostname, so dns and platform reference each
  # other. Terraform will reject this as a cycle. Fix on first apply by either
  #   (a) splitting dns/ into a zone submodule and a records submodule, or
  #   (b) bootstrapping once with
  #       terraform apply -target=module.dns.aws_route53_zone.zone
  # (a) is the right answer; (b) is enough to get a first environment up.
  route53_zone_id   = module.dns.zone_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  host_store        = local.host_store
  host_sales        = local.host_sales
  host_admin        = local.host_admin
  host_dashboard    = local.host_dashboard

  depends_on = [module.eks]
}

# The portable workloads — the exact module local/ and gcp/ deploy.
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

  storage_class          = var.storage_class
  namespace_memory_quota = var.namespace_memory_quota
  kc_hostname            = local.host_store

  # Left "true" to match gcp. Despite the name this does not relax security: the
  # uam image selects the realm from MOCKTEN_MODE first, and "false" historically
  # made it import the image's own realm, which hardcodes localhost and has
  # directAccessGrantsEnabled false — every login then fails.
  kc_dev_mode    = "true"
  public_origins = local.public_origins

  mockten_mode       = "cloud"
  public_base_domain = var.root_domain

  # _enabled is a literal, never `secret != ""`. The secret's value is unknown
  # until apply, and a count may not depend on that — getting this wrong breaks
  # `terraform destroy` as well as apply.
  dashboard_session_secret_enabled = true
  dashboard_session_secret         = random_password.dashboard_session.result

  kc_admin_password  = random_password.kc_admin.result
  e2e_admin_enabled  = true
  e2e_admin_user     = "e2e-admin@${var.root_domain}"
  e2e_admin_password = random_password.e2e_admin.result

  depends_on = [module.eks]
}
