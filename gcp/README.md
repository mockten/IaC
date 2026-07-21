# Mockten on GKE

Deploys the full mockten platform to a **regional GKE Autopilot** cluster with
HTTPS on `example.dpdns.org`, locked to a single source IP, and Cloud DNS
delegated to the DigitalPlat registrar automatically.

This is the same `common/k8s` workloads that `local/` deploys — only the
environment layer (cluster, network, ingress, DNS, TLS) differs. See
`../MOCKTEN_REQUESTS.md` history and `local/` for the docker-desktop counterpart.

## Architecture

| Layer | Resource |
|---|---|
| Network | custom VPC + subnet (secondary ranges for pods/services) + **Cloud NAT** (private nodes need it to pull ghcr images) |
| Cluster | GKE **Standard**, zonal, small node pool, private nodes, public control-plane endpoint locked to `allowlist_cidr` |
| Ingress | nginx-ingress, pinned to a reserved regional IP, L4 firewall narrowed to `allowlist_cidr` via `loadBalancerSourceRanges` |
| TLS | cert-manager, Let's Encrypt **DNS-01** over Cloud DNS (via Workload Identity) — issues with no inbound 80/443, so it works behind the IP lock |
| DNS | Cloud DNS zone + A records for the 4 hosts; nameservers **pushed to the registrar automatically** (terracurl) |
| Workloads | `module.common_k8s` — the 21 mockten services, unchanged |

**Why Standard, not Autopilot:** Autopilot injects a 0.5 vCPU / 2 GiB request
into every pod that doesn't declare one. For mockten's ~21 small services that
balloons to ~10 vCPU / ~42 GiB, blowing past the namespace ResourceQuota and a
fresh project's GCE quota, so nothing schedules. Standard runs the pods
best-effort and packs them onto a 2-node pool — exactly like the local
single-node cluster. GKE Standard still ships metrics-server managed, so the
dashboard's CPU/Memory works.

**DNS delegation is automatic — no manual step.** `terracurl` PATCHes the zone's
nameservers to the DigitalPlat API on every apply, so a destroy/apply cycle that
lands a different nameserver set self-heals. Two non-obvious requirements, both
already encoded:

- The request **must** send a browser `User-Agent` (and `Accept: application/json`).
  The API is behind a WAF that serves a Cloudflare challenge page (403 `text/html`)
  to default client user-agents; the symptom is
  `serializer for text/html doesn't exist` on every apply.
- There is deliberately **no `destroy_*` block**. Teardown should leave the
  delegation alone, and a destroy-time call would hit the same `text/html` and
  block `terraform destroy`.

Certificates then issue on their own once the delegation propagates.

Hosts: `example.dpdns.org` (storefront), `sales.` (seller portal, redirects to
`/seller/login`), `admin.` (`/admin`), `dashboard.` (dashboard).

## Prerequisites (one-time, per fresh clone / project)

The steps a first-time operator must run before `terraform apply`. Most are
gcloud; do them once per GCP project.

```sh
PROJECT=ethereal-app-502613-p1
REGION=us-east1

# 1. Billing must be linked, or every API enable and the cluster create fail.
gcloud billing projects link "$PROJECT" --billing-account=<ACCOUNT_ID>

# 2. Enable the APIs the stack uses.
gcloud services enable \
  container.googleapis.com compute.googleapis.com dns.googleapis.com \
  servicenetworking.googleapis.com cloudresourcemanager.googleapis.com \
  iam.googleapis.com iamcredentials.googleapis.com --project "$PROJECT"

# 3. GCS bucket for Terraform remote state (name is passed to `init`).
gcloud storage buckets create "gs://${PROJECT}-tfstate" --project "$PROJECT" --location "$REGION"

# 4. Claim the domain at DigitalPlat (dash.domain.digitalplat.org) and mint an
#    API token (dp_live_...). The NS delegation is then pushed automatically.
```

Nothing else is created by hand — the cert-manager Workload Identity service
account, IAM bindings, DNS zone, and all cluster resources are Terraform-managed.

## Configuration

Terraform reads everything from `TF_VAR_*` (never a committed tfvars). Locally,
the repo `.env` (gitignored) is exported by the Taskfile; in CI they come from
GitHub secrets. Required variables:

| Variable | Notes |
|---|---|
| `github_username` / `github_token` / `github_email` | ghcr image pull |
| `google_client_id` / `google_client_secret` / `facebook_*` | Keycloak SSO |
| `stripe_secret_key` / `stripe_public_key` | payments |
| `domain_api_key` | DigitalPlat bearer token (`dp_live_...`) |
| `allowlist_cidr` | the one IP allowed at the ingress + control plane (default = home IP) |

## Apply

```sh
cd gcp
terraform init -backend-config="bucket=${PROJECT}-tfstate"
terraform apply
```

One `terraform apply` from an empty state builds everything — network, cluster,
node pool, ingress, cert-manager, DNS + delegation, and all 21 workloads (78
resources, ~20 min). No `-target` phases and no manual steps, so it drops
straight into a CD pipeline.

After apply:

- `terraform output name_servers` — already pushed to the registrar.
- Certificates issue on their own once delegation propagates (usually a few
  minutes). Watch `kubectl get certificate -A` until all are `READY=True`.
- Then `curl -sI https://example.dpdns.org` returns 200 **from the allowlisted
  IP only**; every other source times out at the load balancer.

To talk to the cluster afterwards:
`gcloud container clusters get-credentials mockten-gke --zone us-east1-b`
(re-run this after any destroy/apply — the endpoint changes).

### Verified parity

`PLAYWRIGHT_BASE_URL=https://example.dpdns.org npx playwright test` from the
mockten repo gives **55 passed / 0 failed / 4 skipped** — the same as local.

## Teardown

```sh
terraform destroy
```

`deletion_protection` is off, PVCs reclaim their PDs, and the registrar NS push
is a read-only GET on destroy (the delegation is left in place; re-point or
release the domain manually if desired).

## GitHub Actions

`../.github/workflows/deploy-to-gcp.yml` runs this manually
(`workflow_dispatch`), authenticating with the `GCP_SA_KEY` secret and injecting
the runner's egress IP into the control-plane allowlist for the run. See that
file's header for the full secret list.
