# Reserved regional external IP for the nginx-ingress LB. Reserved up front so the
# DNS A records and the LB agree at plan time (no "wait for the LB IP" dance).
resource "google_compute_address" "ingress" {
  name   = "mockten-ingress-ip"
  region = var.region
}

# Kept in state rather than generated per-start in the container, so a dashboard
# restart does not log every operator out. Never leaves Terraform state.
resource "random_password" "dashboard_session" {
  length  = 48
  special = false
}

# The E2E admin's password. Generated so it never passes through .env, a
# document, or a chat message — the E2E run reads it from `terraform output`.
resource "random_password" "e2e_admin" {
  length  = 32
  special = false
}

# Keycloak's master-realm admin, replacing the image's admin/admin default.
resource "random_password" "kc_admin" {
  length  = 32
  special = false
}

module "nw" {
  source = "./nw"
  region = var.region
}

module "gke" {
  source                  = "./gke"
  project                 = var.project
  cluster_name            = var.cluster_name
  zone                    = var.zone
  network_self_link       = module.nw.network_self_link
  subnet_self_link        = module.nw.subnet_self_link
  pods_range_name         = module.nw.pods_range_name
  services_range_name     = module.nw.services_range_name
  allowlist_cidr          = var.allowlist_cidr
  master_authorized_extra = var.master_authorized_extra
}

module "dns" {
  source              = "./dns"
  root_domain         = var.root_domain
  ingress_ip          = google_compute_address.ingress.address
  domain_api_base_url = var.domain_api_base_url
  domain_api_key      = var.domain_api_key
}

module "platform" {
  source                 = "./platform"
  project                = var.project
  ingress_ip             = google_compute_address.ingress.address
  allowlist_cidr         = var.allowlist_cidr
  egress_cidr            = "${module.nw.nat_ip}/32"
  letsencrypt_email      = var.letsencrypt_email
  acme_staging           = var.acme_staging
  workload_identity_pool = module.gke.workload_identity_pool
  dns_zone_name          = module.dns.zone_name
  host_store             = local.host_store
  host_sales             = local.host_sales
  host_admin             = local.host_admin
  host_dashboard         = local.host_dashboard

  depends_on = [module.gke]
}

# The portable workloads — identical module to the one `local` deploys, with the
# per-environment knobs supplied. kc_dev_mode=false and public_origins carry the
# real HTTPS hosts so Keycloak/Google login work behind TLS.
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

  # Left "true" deliberately. This used to be load-bearing for realm selection:
  # "false" made uam import the realm baked into the image, which hardcoded
  # http://localhost/* and had directAccessGrantsEnabled: false, so every login
  # failed with "Client not allowed for direct access grants". mockten now
  # selects the realm from MOCKTEN_MODE instead, and realm-export-cloud.json
  # fixes both problems at the source — but whether DEV_MODE still influences
  # anything in the new image has not been verified here, so this stays as the
  # value that is known to work. Worth revisiting once cloud login is confirmed.
  kc_dev_mode    = "false"
  public_origins = local.public_origins

  # The cloud deployment shape: dashboard login, host-split portal links, the
  # HTTPS READY condition, and the cloud realm. Distinct from kc_dev_mode/
  # DEV_MODE above, which is about how containers are inspected — see the note
  # in common/k8s/variables.tf.
  mockten_mode       = "cloud"
  public_base_domain = var.root_domain

  # A fresh cloud cluster has zero purchases, so the recommendation pipeline has
  # nothing to train on. Run the in-cluster behavior seeder to populate purchase
  # data and kick off training (local seeds via the Taskfile instead).
  enable_seed_job = true

  # _enabled is the literal true, NOT `secret != ""` — the secret's value is
  # unknown until apply, and a count may not depend on that.
  dashboard_session_secret_enabled = true
  dashboard_session_secret         = random_password.dashboard_session.result

  # Same rule as above: _enabled is a literal, the value is generated. The
  # password is never printed, committed, or passed through .env — it lives in
  # Terraform state and a k8s Secret, and `terraform output` is the only way to
  # read it (see outputs.tf).
  e2e_admin_enabled  = true
  e2e_admin_user     = "e2e-admin@${var.root_domain}"
  e2e_admin_password = random_password.e2e_admin.result

  # Replaces the image's admin/admin default. Read it back, if ever needed, with
  # `terraform output -raw kc_admin_password`.
  kc_admin_password = random_password.kc_admin.result

  depends_on = [module.gke]
}
