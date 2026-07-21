# In-cluster ingress + TLS. Kept deliberately parallel to local/k8s (nginx-ingress),
# so the same model carries to Azure/AWS: only the LB IP, the IP allowlist and the
# DNS-01 solver are cloud-specific.

# ── nginx-ingress controller ─────────────────────────────────────────────────
# Pinned to the reserved regional IP, and the L4 LB firewall is narrowed to the
# home IP via loadBalancerSourceRanges (network-level, not just an nginx 403).
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
        loadBalancerSourceRanges = [var.allowlist_cidr]
        externalTrafficPolicy    = "Local"
      }
    }
  })]
}

# ── cert-manager + Workload Identity for the DNS-01 solver ───────────────────
resource "google_service_account" "certmgr" {
  account_id   = "cert-manager-dns01"
  display_name = "cert-manager DNS-01 solver"
  project      = var.project
}

# Narrowest role that still lets the ACME solver write/cleanup _acme-challenge TXT.
resource "google_project_iam_member" "certmgr_dns" {
  project = var.project
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.certmgr.email}"
}

# Let the cert-manager KSA impersonate the GCP SA (Workload Identity).
resource "google_service_account_iam_member" "certmgr_wi" {
  service_account_id = google_service_account.certmgr.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.workload_identity_pool}[cert-manager/cert-manager]"
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
    serviceAccount = {
      annotations = {
        "iam.gke.io/gcp-service-account" = google_service_account.certmgr.email
      }
    }
    # By default cert-manager verifies DNS-01 propagation by querying the
    # domain's authoritative nameservers directly. For a dpdns.org subdomain the
    # parent's servers answer SERVFAIL / time out from inside the cluster
    # ("dial tcp 142.171.123.133:53: i/o timeout"), so the challenge never
    # self-checks even though the TXT record is correctly published in Cloud DNS.
    # Check via public recursive resolvers instead.
    extraArgs = [
      "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
      "--dns01-recursive-nameservers-only",
    ]
  })]
}

# ── ACME ClusterIssuer (Let's Encrypt, DNS-01 over Cloud DNS) ────────────────
# DNS-01 proves control via a TXT record, so no inbound 80/443 is needed — it
# issues fine behind the IP lock. kubectl_manifest (not kubernetes_manifest) so
# the CR applies without a plan-time CRD check.
resource "kubectl_manifest" "cluster_issuer" {
  depends_on = [helm_release.cert_manager]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt" }
    spec = {
      acme = {
        # Let's Encrypt allows 5 certificates per exact set of identifiers per
        # 168h. This stack tears down and rebuilds whole, and each rebuild asks
        # for the same four hostnames, so five rebuilds in a week exhaust the
        # quota and every Order fails with 429 — which looks like a DNS or
        # cert-manager fault but is neither. That happened on 2026-07-20.
        #
        # Iterate on staging (effectively unlimited, but the CA is untrusted so
        # browsers warn), and switch to production for the run that has to be
        # demonstrable.
        server = var.acme_staging ? (
          "https://acme-staging-v02.api.letsencrypt.org/directory"
          ) : (
          "https://acme-v02.api.letsencrypt.org/directory"
        )
        email = var.letsencrypt_email
        # Separate account keys per environment: an account registered against
        # staging is not valid against production, so reusing one secret across
        # a switch fails to register.
        privateKeySecretRef = {
          name = var.acme_staging ? "letsencrypt-account-key-staging" : "letsencrypt-account-key"
        }
        solvers = [{
          dns01 = {
            cloudDNS = {
              project = var.project
              # hostedZoneName is REQUIRED here, not optional. Without it
              # cert-manager auto-detects the zone by walking up to the
              # registrable domain — for example.dpdns.org that lands on
              # "dpdns.org" (since .org is the public suffix), and it fails with
              # "No matching GoogleCloud domain found for domain dpdns.org."
              # because the zone we own is example.dpdns.org. Naming the zone
              # explicitly skips that detection.
              hostedZoneName = var.dns_zone_name
            }
          }
        }]
      }
    }
  })
}
