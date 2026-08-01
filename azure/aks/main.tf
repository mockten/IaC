# The AKS cluster — the Azure counterpart to gcp/gke.
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name       = "primary"
    node_count = var.node_count
    # 2 x D2s_v7 = 4 vCPU total, which fits a trial subscription's tiny regional
    # vCPU quota (often just 4). Two nodes (not one bigger node) so the ~35 pods
    # — the ~21 app pods plus kube-system — get enough pod slots; a single node
    # runs out of slots before CPU and leaves pods stuck Pending.
    # v7 not v5: trial/free subscriptions restrict the allowed SKUs per region —
    # D-series v5 is blocked in eastus, v7 is available.
    vm_size        = var.vm_size
    vnet_subnet_id = var.subnet_id
  }

  identity {
    type = "SystemAssigned"
  }

  # The equivalent of GKE's master_authorized_networks: the API server admits the
  # home IP(s) plus, per-run, the CI runner (master_authorized_extra).
  api_server_access_profile {
    authorized_ip_ranges = concat([for c in split(",", var.allowlist_cidr) : trimspace(c)], var.master_authorized_extra)
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # AGIC (Application Gateway Ingress Controller) as a managed add-on, brownfield:
  # it programs the Terraform-owned Application Gateway (../appgw) from the cluster
  # Ingresses. This is the Azure cloud-native ingress — the counterpart to the AWS
  # Load Balancer Controller — replacing ingress-nginx. AGIC gets a managed
  # identity here; the role assignments it needs are made at the root.
  ingress_application_gateway {
    gateway_id = var.appgw_id
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }
}
