# Host-based Ingresses programmed onto the Application Gateway by AGIC — the Azure
# counterpart to aws/routing. Same host/path map as the other clouds; only the
# mechanism (AGIC + App Gateway rules) differs. TLS is terminated at Front Door,
# which reaches the gateway over HTTP, so there is no cert here.
#
# Runs after common_k8s (the backend Services must exist) and after the AGIC role
# assignments (so AGIC can program the gateway).
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}
