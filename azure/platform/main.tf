# ingress-nginx, cert-manager and the ClusterIssuer — the Azure counterpart to
# gcp/platform. The ingress objects live in ingress.tf.
terraform {
  required_providers {
    azurerm    = { source = "hashicorp/azurerm" }
    helm       = { source = "hashicorp/helm" }
    kubectl    = { source = "gavinbunney/kubectl" }
    kubernetes = { source = "hashicorp/kubernetes" }
  }
}

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
        loadBalancerIP           = var.ingress_ip
        loadBalancerSourceRanges = [for c in split(",", var.allowlist_cidr) : trimspace(c)]
        externalTrafficPolicy    = "Local"
        annotations = {
          "service.beta.kubernetes.io/azure-load-balancer-resource-group" = var.node_resource_group
        }
      }
    }
  })]
}

# cert-manager needs DNS Zone Contributor on the zone to write _acme-challenge.
resource "azurerm_role_assignment" "certmgr_dns" {
  scope                = var.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = var.kubelet_object_id
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
    # Self-checking DNS-01 against the domain's authoritative nameservers fails for
    # a delegated subdomain — the parent's servers SERVFAIL or time out from inside
    # the cluster even though the TXT record is published. Check via public
    # resolvers instead.
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
        # Production allows 5 certificates per identifier set per 168h; a stack that
        # rebuilds whole exhausts that in five rebuilds and then every Order fails
        # 429, which looks like a DNS fault but is not.
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
              subscriptionID    = var.subscription_id
              resourceGroupName = var.resource_group_name
              hostedZoneName    = var.dns_zone_name
              environment       = "AzurePublicCloud"
              managedIdentity = {
                clientID = var.kubelet_client_id
              }
            }
          }
        }]
      }
    }
  })
}
