# Root wiring for mockten on EKS — the AWS counterpart to gcp/main.tf and
# azure/main.tf. Each concern is a module (nw / eks / dns / platform), all
# consuming the same common/k8s workloads module GKE and AKS deploy.
#
# Ordering note: on GCP/Azure the LB IP is reserved up front so DNS and platform
# build in parallel. An AWS NLB only gets its hostname once the Service exists,
# so the A records are owned by the platform module (records.tf), and dns/ holds
# only the zone. That keeps dns -> platform one-directional (no module cycle):
# platform reads the zone id; the records read the platform's NLB hostname.

# ── Derived hostnames (identical split to gcp/azure) ─────────────────────────
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
}

# gp3 StorageClass, created here (not in the eks module) so the kubernetes
# provider — which is configured from eks outputs — is not consumed by a resource
# living inside that same module, which Terraform rejects as a cycle. EKS ships
# gp2 as default; gp3 is cheaper and faster. Depends on the whole eks module so
# the EBS CSI addon and node group exist first.
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = var.storage_class
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  # WaitForFirstConsumer, so a volume is created in the AZ the pod lands in.
  # Immediate binding on a multi-AZ cluster can place the disk where the pod
  # cannot reach it.
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type = "gp3"
  }
  depends_on = [module.eks]
}

# Zone only. The A records that alias the NLB live in the platform module.
module "dns" {
  source                = "./dns"
  root_domain           = var.root_domain
  domain_api_base_url   = var.domain_api_base_url
  domain_api_key        = var.domain_api_key
  domain_api_user_agent = var.domain_api_user_agent
  enable_ns_push        = var.enable_ns_push
}

module "platform" {
  source       = "./platform"
  region       = var.region
  cluster_name = var.cluster_name
  vpc_id       = module.nw.vpc_id

  route53_zone_id   = module.dns.zone_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  host_store        = local.host_store
  host_sales        = local.host_sales
  host_admin        = local.host_admin
  host_dashboard    = local.host_dashboard

  depends_on = [module.eks]
}

# The portable workloads — the exact module local/, gcp/ and azure/ deploy.
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

  # Left "true" to match gcp/azure. Despite the name this does not relax
  # security: the uam image selects the realm from MOCKTEN_MODE first, and
  # "false" historically made it import the image's own realm, which hardcodes
  # localhost and has directAccessGrantsEnabled false — every login then fails.
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

  # Seed purchase data + train the model so the dashboard reads all-READY on
  # first open. Unlike gcp/azure there is no internal_ingress_ip hostAlias: an ALB
  # has no in-cluster ClusterIP to point at, so instead the cluster's NAT egress
  # IP is allowed on the ALB (see platform/ingress.tf), and the dashboard reaches
  # its readiness endpoint through the ALB the normal way.
  enable_seed_job = true

  # Ordering:
  #  - kubernetes_storage_class.gp3 before the stateful PVCs (minio/mysql/meili).
  #  - module.platform before ANY workload Service: the AWS Load Balancer
  #    Controller installs a mutating webhook that intercepts every Service
  #    creation, so the workloads must wait until its pods are Ready or the
  #    webhook call fails with "no endpoints available".
  depends_on = [module.eks, kubernetes_storage_class.gp3, module.platform]
}

# The ALB Ingresses + DNS records. Created LAST: the controller builds a target
# group per backend Service, so those Services (from common_k8s) must already
# exist, or the ALB never provisions and data.aws_lb finds nothing.
module "routing" {
  source              = "./routing"
  vpc_id              = module.nw.vpc_id
  acm_certificate_arn = module.platform.acm_certificate_arn
  host_store          = local.host_store
  host_sales          = local.host_sales
  host_admin          = local.host_admin
  host_dashboard      = local.host_dashboard

  depends_on = [module.common_k8s]
}

# CloudFront in front of the ALB: edge-caches images + static assets, keeps the
# site private via a WAF IP-set, and owns the four A records (they alias
# CloudFront, not the ALB). The us-east-1 provider is required for the CloudFront
# viewer cert and the WebACL.
module "cdn" {
  source    = "./cdn"
  providers = { aws.us_east_1 = aws.us_east_1 }

  allowlist_cidr  = var.allowlist_cidr
  nat_public_ip   = module.nw.nat_public_ip
  route53_zone_id = module.dns.zone_id
  alb_dns_name    = module.routing.alb_dns_name
  host_store      = local.host_store
  host_sales      = local.host_sales
  host_admin      = local.host_admin
  host_dashboard  = local.host_dashboard
}
