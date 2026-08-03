terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}
