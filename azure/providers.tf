# DRAFT — never applied. Mirrors gcp/ so the same common/k8s module runs on AKS.
#
# NOTE: this directory still contains an older VM-based design (fw/, vmss/, and
# the legacy main.tf/variables.tf). Those modules are not referenced by aks.tf
# and are left in place rather than deleted. Remove them once this draft is
# proven, or move them to azure/legacy/.
terraform {
  required_version = ">= 1.9.0"

  backend "azurerm" {
    resource_group_name  = "mockten-tfstate-rg"
    storage_account_name = "mocktentfstate"
    container_name       = "tfstate"
    key                  = "mockten.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.10"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "~> 1.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      # Without this a `terraform destroy` can leave the resource group behind
      # holding orphaned disks, which keep billing.
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Credentials come straight off the cluster resource, so there is no kubeconfig
# on disk and no context to mis-point — the failure mode that once had a local
# command delete a cloud cluster's volumes.
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.this.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.this.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.this.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.this.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.this.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.this.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.this.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.this.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.this.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config.0.cluster_ca_certificate)
  load_config_file       = false
}
