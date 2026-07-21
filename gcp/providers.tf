terraform {
  required_version = ">= 1.5"

  # Remote state in GCS. Bucket is supplied at init so it isn't hardcoded:
  #   terraform init -backend-config="bucket=<project>-tfstate"
  backend "gcs" {
    prefix = "gcp/terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    # Applies CRs (cert-manager ClusterIssuer) at apply-time without the
    # plan-time CRD check that hashicorp/kubernetes_manifest imposes.
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    # PATCHes the registrar's nameservers over its REST API (no official provider).
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "~> 1.2"
    }
    # Holds the dashboard's session signing key in state, so restarts don't log
    # every operator out.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

# Short-lived token for the kubernetes/helm/kubectl providers to reach the GKE
# control plane. Configuring the providers from the cluster resource's computed
# endpoint is the standard single-apply bootstrap; if a cold apply ever fails on
# unknown values, apply -target=module.gke first, then the full apply.
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

provider "kubectl" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  load_config_file       = false
}
