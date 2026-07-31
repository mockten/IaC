# mockten on AKS

Terraform for the mockten platform on **Azure Kubernetes Service (AKS)** — the Azure
sibling of [`gcp/`](../gcp). It stands up a private AKS cluster, VNet, a public ingress
IP, a Cloud DNS zone with automatic nameserver delegation, ingress-nginx + cert-manager
(Let's Encrypt), and the portable `common/k8s` workloads — the same module GKE deploys.

One `terraform apply` from an empty subscription builds everything and the dashboard
reads all-READY. It runs from CI via **Azure 2.Deploy** (manual) and is torn down by
**Azure 3.Destroy** (manual). `terraform apply` is idempotent: if a run fails partway,
run it again and it continues from where it stopped.

> The old VM-based design (`main.tf`, `variables.tf`, `nw/`, `fw/`, `vmss/`) has been
> moved to [`legacy/`](legacy) and is not part of this root.

## Prerequisites (one-time, per fresh clone / subscription)

Run these once with the Azure CLI before the first `terraform init`.

```sh
LOCATION=eastus            # region for the tfstate backend (resources default to eastus2)

# 1. Sign in and pick the subscription.
az login
SUB=$(az account show --query id -o tsv)
TENANT=$(az account show --query tenantId -o tsv)

# 2. Register the resource providers the stack uses. A brand-new subscription has
#    these unregistered, which surfaces as a confusing "SubscriptionNotFound" when
#    you first create a storage account or cluster. The azurerm provider auto-
#    registers most of these during apply, but the tfstate storage account is
#    created OUTSIDE Terraform (below), so register Microsoft.Storage up front.
for ns in Microsoft.Storage Microsoft.Network Microsoft.Compute \
          Microsoft.ContainerService Microsoft.ManagedIdentity \
          Microsoft.OperationalInsights Microsoft.KeyVault; do
  az provider register --namespace "$ns"
done
az provider register --namespace Microsoft.Storage --wait

# 3. Remote state: a Storage Account + blob container. The backend config in
#    providers.tf is hardcoded to these names — change both if you use different ones.
#    Storage-account names are globally unique; if "mocktentfstate" is taken, pick
#    another and update providers.tf's `storage_account_name`.
az group create -n mockten-tfstate-rg -l "$LOCATION"
az storage account create -n mocktentfstate -g mockten-tfstate-rg -l "$LOCATION" --sku Standard_LRS
KEY=$(az storage account keys list -g mockten-tfstate-rg -n mocktentfstate --query "[0].value" -o tsv)
az storage container create -n tfstate --account-name mocktentfstate --account-key "$KEY"

# 4. Deploy service principal. Its four fields become the ARM_* secrets/.env values.
#    Owner keeps AKS role assignments from tripping over permissions on a throwaway
#    subscription; scope it tighter if you prefer least-privilege.
az ad sp create-for-rbac --name mockten-deployer --role Owner --scopes /subscriptions/$SUB
#    Map the output: appId -> ARM_CLIENT_ID, password -> ARM_CLIENT_SECRET,
#    tenant -> ARM_TENANT_ID, and $SUB -> ARM_SUBSCRIPTION_ID.
```

Nothing else is created by hand — the AKS cluster, VNet, DNS zone + delegation, and all
cluster resources are Terraform-managed.

## Configuration

Terraform reads everything from `TF_VAR_*` and `ARM_*` (never a committed tfvars).
Locally the repo `.env` (gitignored) supplies them; in CI they come from GitHub secrets.

| Variable | Notes |
|---|---|
| `ARM_CLIENT_ID` / `ARM_CLIENT_SECRET` / `ARM_SUBSCRIPTION_ID` / `ARM_TENANT_ID` | the deploy service principal (step 4) |
| `github_username` / `github_token` / `github_email` | ghcr image pull |
| `google_client_id` / `google_client_secret` / `facebook_*` | Keycloak SSO |
| `stripe_secret_key` / `stripe_public_key` | payments |
| `domain_api_key` | DigitalPlat bearer token for the nameserver push |
| `allowlist_cidr` | CIDR(s) allowed at the ingress + the AKS API server; comma-separated for several people |
| `root_domain` / `letsencrypt_email` | apex domain and ACME account email |

The GitHub Actions secret list (with the `GITHUB_* -> GH_*` rename and the cloud-vs-dev
OAuth guidance) is documented once in the top-level [README](../README.md#github-actions-secrets).
Azure needs **only the `AZURE_*` secrets in addition** to that shared set — no
`GCP_SA_KEY`, no `repo_pat`.

## Apply

```sh
cd azure
terraform init
terraform apply
```

Or run **Azure 2.Deploy** from the Actions tab. After apply, Terraform pushes the
nameserver delegation to the registrar and cert-manager issues the four certificates
once delegation propagates. The ingress and the AKS API server are locked to
`ALLOWLIST_CIDR`.

## Teardown

Run **Azure 3.Destroy** (type the subscription id to confirm), or `terraform destroy`
locally. Destroy deletes everything Terraform manages **plus** the billing resources it
does not track — the AKS node resource group (`MC_*`) and its dynamically-provisioned
PVC managed disks — so nothing keeps costing afterward. The `mockten-tfstate-rg` backend
is intentionally preserved. `keep_dns_zone: true` keeps the DNS zone + delegation to skip
re-delegation on the next apply.

## Region / SKU notes (Azure free-trial gotchas)

A brand-new trial subscription is heavily constrained; the defaults here are chosen to fit:

- **Kubernetes version** (`az_kubernetes_version`, default `1.34`) must be a **GA
  (`KubernetesOfficial`)** version, not an LTS-only one. `1.31`–`1.33` are LTS-only in
  eastus and fail with `K8sVersionNotSupported`. Check:
  `az aks get-versions --location <loc> --query "values[?contains(capabilities.supportPlan, 'KubernetesOfficial')].version"`.
- **VM size** (default `Standard_D2s_v7`, 2 nodes = 4 vCPU): trial subscriptions
  restrict the allowed SKUs per region — D-series **v5** is blocked in eastus, **v7** is
  available. Two small nodes (not one bigger) so the ~35 pods get enough pod slots.
- **Regional vCPU quota** is often just **4** — hence 2 × D2s_v7. Raising it needs a quota
  request; then bump node count / size.
- **Region** (`az_location`, default `eastus2`): eastus frequently returns
  `AKSCapacityHeavyUsage` (region at capacity for new clusters). All regions share the
  same trial vCPU quota, so moving is free — pick one that can currently create a cluster.
