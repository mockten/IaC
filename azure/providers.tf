# Providers and remote state for the AKS root. Mirrors gcp/ so the same
# common/k8s module runs on AKS. The kubernetes/helm/kubectl providers are
# configured from the aks module's kube_config outputs.
#
# The older VM-based design lives in azure/legacy/ and is not part of this root.
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

# Credentials come straight off the cluster (via the aks module outputs), so there
# is no kubeconfig on disk and no context to mis-point.
provider "kubernetes" {
  host                   = module.aks.kube_host
  client_certificate     = base64decode(module.aks.kube_client_certificate)
  client_key             = base64decode(module.aks.kube_client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kube_host
    client_certificate     = base64decode(module.aks.kube_client_certificate)
    client_key             = base64decode(module.aks.kube_client_key)
    cluster_ca_certificate = base64decode(module.aks.kube_cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = module.aks.kube_host
  client_certificate     = base64decode(module.aks.kube_client_certificate)
  client_key             = base64decode(module.aks.kube_client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_cluster_ca_certificate)
  load_config_file       = false
}
