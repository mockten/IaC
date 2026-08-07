# cert-manager + the Let's Encrypt ClusterIssuer — TLS for the AGIC/Application
# Gateway ingress. Azure Front Door (which would have given managed certs) is
# forbidden on Free Trial subscriptions, so TLS is issued the same way gcp/ does
# it: cert-manager with a DNS-01 solver against the Azure DNS zone, via the
# cluster's kubelet managed identity. AGIC then serves the issued secret on the
# gateway's HTTPS listener. No ingress-nginx — AGIC is the controller.
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
    helm    = { source = "hashicorp/helm" }
    kubectl = { source = "gavinbunney/kubectl" }
  }
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
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-account-key"
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
