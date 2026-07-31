# AKS cluster, DNS zone, ingress and the portable workloads — the Azure
# counterpart to gcp/main.tf. Kept in one file because Azure needs fewer moving
# parts than AWS: no OIDC provider to construct, no subnet tagging contract, and
# a CSI driver that is enabled by default.
#
# DRAFT — never applied.

# ── Variables specific to this draft ─────────────────────────────────────────
variable "az_location" {
  # eastus frequently returns AKSCapacityHeavyUsage (region at capacity for new
  # clusters). All regions share the same tiny trial vCPU quota (4), so moving is
  # free — just pick one that can currently create a cluster. The tfstate backend
  # stays in eastus regardless (backend region need not match the resources').
  description = "Azure region for the cluster and its resource group."
  type        = string
  default     = "eastus2"
}

variable "az_resource_group" {
  type    = string
  default = "mockten-rg"
}

variable "az_cluster_name" {
  type    = string
  default = "mockten-aks"
}

variable "az_kubernetes_version" {
  # Pinned: an unpinned version silently upgrades on re-apply. Use a supported GA
  # minor — the "1.31" alias now resolves to an LTS-only patch (K8sVersionNotSupported
  # on a Free/Standard cluster). Check the region's list: az aks get-versions --location <loc>.
  description = "Pinned AKS minor version. Must be a GA (KubernetesOfficial) version, not LTS-only — check with: az aks get-versions --location <loc> --query \"values[?contains(capabilities.supportPlan, 'KubernetesOfficial')].version\"."
  type        = string
  default     = "1.34"
}

variable "az_storage_class" {
  description = "managed-csi is the default AKS class and binds WaitForFirstConsumer, which is what the minio and mysql PVCs need."
  type        = string
  default     = "managed-csi"
}

locals {
  az_host_store     = var.root_domain
  az_host_sales     = "sales.${var.root_domain}"
  az_host_admin     = "admin.${var.root_domain}"
  az_host_dashboard = "dashboard.${var.root_domain}"

  az_public_origins = [
    "https://${local.az_host_store}",
    "https://${local.az_host_sales}",
    "https://${local.az_host_admin}",
    "https://${local.az_host_dashboard}",
  ]
}

resource "random_password" "az_dashboard_session" {
  length  = 48
  special = false
}
resource "random_password" "az_e2e_admin" {
  length  = 32
  special = false
}
resource "random_password" "az_kc_admin" {
  length  = 32
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = var.az_resource_group
  location = var.az_location
}

# ── Cluster ──────────────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "this" {
  name                = var.az_cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.az_cluster_name
  kubernetes_version  = var.az_kubernetes_version

  default_node_pool {
    name       = "primary"
    node_count = 2
    # 2 x D2s_v7 = 4 vCPU total, which fits a trial subscription's tiny regional
    # vCPU quota (often just 4). Two nodes (not one bigger node) so the ~35 pods
    # — the ~21 app pods plus kube-system — get enough pod slots; a single node
    # runs out of slots before CPU and leaves pods stuck Pending. Bump to
    # D4s_v7 / more nodes once the subscription quota is raised.
    # v7 not v5: trial/free subscriptions restrict the allowed SKUs per region —
    # D-series v5 is blocked in eastus, v7 is available (az vm list-skus
    # --location <loc> --resource-type virtualMachines).
    vm_size    = "Standard_D2s_v7"
    vnet_subnet_id = azurerm_subnet.nodes.id
  }

  identity {
    type = "SystemAssigned"
  }

  # The equivalent of GKE's master_authorized_networks. Same rule as the other
  # clouds: the API server admits the home IP plus, per-run, the CI runner.
  api_server_access_profile {
    authorized_ip_ranges = concat([for c in split(",", var.allowlist_cidr) : trimspace(c)], var.master_authorized_extra)
  }

  # Workload Identity, so cert-manager can touch the DNS zone without a secret.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "mockten-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.40.0.0/16"]
}

resource "azurerm_subnet" "nodes" {
  name                 = "nodes"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.40.0.0/20"]
}

# Reserved up front so the DNS records and the LB agree at plan time — the same
# trick gcp/ uses, and the reason Azure needs no dns/platform ordering dance.
resource "azurerm_public_ip" "ingress" {
  name                = "mockten-ingress-ip"
  location            = azurerm_resource_group.main.location
  # Must live in the AKS-managed node resource group, or the LB cannot claim it.
  resource_group_name = azurerm_kubernetes_cluster.this.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ── DNS ──────────────────────────────────────────────────────────────────────
resource "azurerm_dns_zone" "zone" {
  name                = var.root_domain
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_dns_a_record" "hosts" {
  for_each = {
    apex      = "@"
    sales     = "sales"
    admin     = "admin"
    dashboard = "dashboard"
  }
  name                = each.value
  zone_name           = azurerm_dns_zone.zone.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_public_ip.ingress.ip_address]
}

# Same registrar push as the other clouds. Two hard-won details carried over:
# the WAF rejects non-browser User-Agents (and the rejection looks like an auth
# failure), and there is deliberately no destroy_* block — the destroy call
# returns text/html, which terracurl cannot deserialise, and that blocks
# `terraform destroy` entirely.
resource "terracurl_request" "ns_delegation" {
  count  = var.enable_ns_push ? 1 : 0
  name   = "ns-delegation"
  url    = "${var.domain_api_base_url}/domains/${var.root_domain}/nameservers"
  method = "PATCH"

  headers = {
    Authorization = "Bearer ${var.domain_api_key}"
    Content-Type  = "application/json"
    Accept        = "application/json"
    User-Agent    = var.domain_api_user_agent
  }

  request_body   = jsonencode({ nameservers = azurerm_dns_zone.zone.name_servers })
  response_codes = ["200", "201", "202", "204"]

  lifecycle {
    replace_triggered_by = [azurerm_dns_zone.zone]
  }
}

# ── Platform ─────────────────────────────────────────────────────────────────
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [yamlencode({
    controller = {
      service = {
        loadBalancerIP           = azurerm_public_ip.ingress.ip_address
        loadBalancerSourceRanges = [for c in split(",", var.allowlist_cidr) : trimspace(c)]
        externalTrafficPolicy    = "Local"
        annotations = {
          "service.beta.kubernetes.io/azure-load-balancer-resource-group" = azurerm_kubernetes_cluster.this.node_resource_group
        }
      }
    }
  })]
}

# cert-manager needs DNS Zone Contributor on the zone to write _acme-challenge.
resource "azurerm_role_assignment" "certmgr_dns" {
  scope                = azurerm_dns_zone.zone.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.16.2"
  namespace        = "cert-manager"
  create_namespace = true

  values = [yamlencode({
    crds = { enabled = true }
    # Self-checking DNS-01 against the domain's authoritative nameservers fails
    # for a delegated subdomain — the parent's servers SERVFAIL or time out from
    # inside the cluster even though the TXT record is published. Cost hours on
    # GCP; check via public resolvers instead.
    extraArgs = [
      "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
      "--dns01-recursive-nameservers-only",
    ]
  })]
}

resource "kubectl_manifest" "cluster_issuer" {
  depends_on = [helm_release.cert_manager]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt" }
    spec = {
      acme = {
        # Production allows 5 certificates per identifier set per 168h; a stack
        # that rebuilds whole exhausts that in five rebuilds and then every Order
        # fails 429, which looks like a DNS fault but is not.
        server = var.acme_staging ? (
          "https://acme-staging-v02.api.letsencrypt.org/directory"
          ) : (
          "https://acme-v02.api.letsencrypt.org/directory"
        )
        email = var.letsencrypt_email
        privateKeySecretRef = {
          name = var.acme_staging ? "letsencrypt-account-key-staging" : "letsencrypt-account-key"
        }
        solvers = [{
          dns01 = {
            azureDNS = {
              subscriptionID    = data.azurerm_client_config.current.subscription_id
              resourceGroupName = azurerm_resource_group.main.name
              hostedZoneName    = azurerm_dns_zone.zone.name
              environment       = "AzurePublicCloud"
              managedIdentity = {
                clientID = azurerm_kubernetes_cluster.this.kubelet_identity[0].client_id
              }
            }
          }
        }]
      }
    }
  })
}

data "azurerm_client_config" "current" {}

# ── Workloads ────────────────────────────────────────────────────────────────
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
  kc_hostname            = local.az_host_store

  # See the note in gcp/main.tf: "true" is the value known to work, because the
  # uam image selects the realm from MOCKTEN_MODE before it looks at DEV_MODE.
  kc_dev_mode    = "true"
  public_origins = local.az_public_origins

  mockten_mode       = "cloud"
  public_base_domain = var.root_domain

  # A count may not depend on a value unknown until apply — hence a literal here
  # and the generated password separately.
  dashboard_session_secret_enabled = true
  dashboard_session_secret         = random_password.az_dashboard_session.result

  kc_admin_password  = random_password.az_kc_admin.result
  e2e_admin_enabled  = true
  e2e_admin_user     = "e2e-admin@${var.root_domain}"
  e2e_admin_password = random_password.az_e2e_admin.result

  # Parity with GCP so the dashboard reads all-READY on first open:
  # - seed purchase data + train the recommendation model on a fresh cluster.
  # - let the dashboard reach the ingress in-cluster for its readiness TLS check
  #   instead of hairpinning to the external LB IP (which times out -> PENDING).
  enable_seed_job     = true
  internal_ingress_ip = data.kubernetes_service.ingress_controller.spec[0].cluster_ip

  depends_on = [azurerm_kubernetes_cluster.this]
}
