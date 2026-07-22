# The namespace's memory budget, and the denominator the dashboard divides
# "Total Memory Usage" by. Without it the dashboard falls back to its own node's
# memory, which is right only on a single-node cluster: on GKE/EKS/AKS the pods
# span nodes, so the numerator counts the whole namespace while the denominator
# is whichever node the dashboard landed on.
#
# `requests.memory`, not `limits.memory`: a quota on either forces every new pod
# in the namespace to declare the matching field, and none of these modules set
# resource limits (see the LimitRange below, which supplies the requests so the
# quota is satisfiable). The dashboard accepts either key.
resource "kubernetes_resource_quota" "mockten" {
  metadata {
    name      = "mockten-quota"
    namespace = "default"
  }
  spec {
    hard = {
      "requests.memory" = var.namespace_memory_quota
    }
  }
  # The LimitRange must exist BEFORE the quota does, never after. The moment the
  # quota exists, every new pod must carry requests.memory or the API server
  # rejects it — and nothing here declares resources, so the LimitRange is what
  # supplies them. Creating the quota first opens a window where ReplicaSets get
  # "forbidden: failed quota: must specify requests.memory", which is how this
  # was found. With this ordering there is no such window: once the quota can
  # reject anything, the defaults are already in place.
  depends_on = [kubernetes_limit_range.mockten]
}

# Supplies the memory request the quota demands, so the modules — none of which
# declare resources — keep scheduling unchanged. Requests only affect placement,
# not OOM behaviour, so this does not cap any container.
resource "kubernetes_limit_range" "mockten" {
  metadata {
    name      = "mockten-defaults"
    namespace = "default"
  }
  spec {
    limit {
      type = "Container"
      default_request = {
        memory = "128Mi"
      }
    }
  }
}

resource "kubernetes_secret" "ghcr" {
  metadata {
    name = "ghcr-secret"
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      "auths" = {
        "https://ghcr.io" = {
          "auth" : base64encode("${var.github_username}:${var.github_token}")
        }
      }
    })
  }
}

module "ecfront" {
  source             = "./ecfront"
  secret_name        = kubernetes_secret.ghcr.metadata[0].name
  stripe_public_key  = var.stripe_public_key
  mockten_mode       = var.mockten_mode
  public_base_domain = var.public_base_domain
}

module "uam" {
  source                 = "./uam"
  secret_name            = kubernetes_secret.ghcr.metadata[0].name
  google_client_id       = var.google_client_id
  google_client_secret   = var.google_client_secret
  facebook_client_id     = var.facebook_client_id
  facebook_client_secret = var.facebook_client_secret
  kc_hostname            = var.kc_hostname
  kc_dev_mode            = var.kc_dev_mode
  redirect_uris          = [for o in var.public_origins : "${o}/*"]
  web_origins            = var.public_origins
  mockten_mode           = var.mockten_mode
  public_base_domain     = var.public_base_domain

  kc_admin_user      = var.kc_admin_user
  kc_admin_password  = var.kc_admin_password
  e2e_admin_enabled  = var.e2e_admin_enabled
  e2e_admin_user     = var.e2e_admin_user
  e2e_admin_password = var.e2e_admin_password
}

module "apigw" {
  source      = "./apigw"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "minio" {
  source        = "./minio"
  secret_name   = kubernetes_secret.ghcr.metadata[0].name
  storage_class = var.storage_class
}

module "meilisearch" {
  source      = "./meilisearch"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "mysql" {
  source        = "./mysql"
  secret_name   = kubernetes_secret.ghcr.metadata[0].name
  storage_class = var.storage_class
}

module "searchitem" {
  source      = "./searchitem"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "product" {
  source      = "./product"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "sync" {
  source      = "./sync"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "redis" {
  source      = "./redis"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "cart" {
  source      = "./cart"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "ecpay" {
  source            = "./ecpay"
  secret_name       = kubernetes_secret.ghcr.metadata[0].name
  stripe_secret_key = var.stripe_secret_key
}

module "ranking" {
  source      = "./ranking"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "sale" {
  source      = "./sale"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "shipment" {
  source      = "./shipment"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "geocoding" {
  source      = "./geocoding"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "recommendation" {
  source      = "./recommendation"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "backdoor" {
  source      = "./backdoor"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "airflow" {
  source      = "./airflow"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
  depends_on  = [module.mysql]
}

module "dashboard" {
  source                 = "./dashboard"
  secret_name            = kubernetes_secret.ghcr.metadata[0].name
  mockten_mode           = var.mockten_mode
  public_base_domain     = var.public_base_domain
  session_secret_enabled = var.dashboard_session_secret_enabled
  session_secret         = var.dashboard_session_secret
}

# In-cluster behavior seeder. Off by default (local seeds via the Taskfile on the
# host); the cloud roots enable it so a fresh apply trains the recommendation
# model instead of leaving it empty. Runs after the data path and the APIs it
# calls are up.
module "seeder" {
  count  = var.enable_seed_job ? 1 : 0
  source = "./seeder"
  image  = var.seeder_image
  depends_on = [
    module.mysql,
    module.product,
    module.apigw,
    module.ranking,
    module.recommendation,
  ]
}
