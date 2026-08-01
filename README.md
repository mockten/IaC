# mockten — IaC

<!-- DryRun -->
[![DryRun(minikube)](https://github.com/mockten/IaC/actions/workflows/dry-run-local.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/dry-run-local.yml)
[![DryRun(GCP)](https://github.com/mockten/IaC/actions/workflows/dry-run-gcp.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/dry-run-gcp.yml)
[![AWS 1.DryRun](https://github.com/mockten/IaC/actions/workflows/dry-run-aws.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/dry-run-aws.yml)
[![DryRun(Azure)](https://github.com/mockten/IaC/actions/workflows/dry-run-azure.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/dry-run-azure.yml)

<!-- Deploy -->
[![Deploy(GCP)](https://github.com/mockten/IaC/actions/workflows/deploy-to-gcp.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/deploy-to-gcp.yml)
[![AWS 2.Deploy](https://github.com/mockten/IaC/actions/workflows/deploy-to-aws.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/deploy-to-aws.yml)
[![Deploy(Azure)](https://github.com/mockten/IaC/actions/workflows/deploy-to-azure.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/deploy-to-azure.yml)

<!-- Destroy -->
[![Destroy(GCP)](https://github.com/mockten/IaC/actions/workflows/destroy-gcp.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/destroy-gcp.yml)
[![AWS 3.Destroy](https://github.com/mockten/IaC/actions/workflows/destroy-aws.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/destroy-aws.yml)
[![Destroy(Azure)](https://github.com/mockten/IaC/actions/workflows/destroy-azure-env.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/destroy-azure-env.yml)

This repository is the **Infrastructure-as-Code** for [**mockten**](https://github.com/mockten/mockten), a full-featured, microservice-based e-commerce platform. The application code lives in the mockten repo; **here we provision and deploy it reproducibly with Terraform** onto Kubernetes — locally (docker-desktop) and on the public-cloud free tiers (GCP / AWS / Azure).

One `terraform apply` from an empty state builds everything — network, cluster, ingress, TLS, DNS delegation, and all the mockten workloads — so it drops straight into a CD pipeline. The same `common/k8s` module is shared across every target, so the surfaces below behave the same wherever they run.

## Platform surfaces

mockten exposes four web surfaces behind one ingress. The path is identical everywhere; only the host changes between a local cluster and a cloud deployment:

| Surface | Local (docker-desktop) | Cloud | Who it's for |
|---------|------------------------|-------|--------------|
| **Mockten storefront** | `http://localhost/` | `https://[YOUR DOMAIN]/` | Buyers — browse, search, cart, checkout |
| **Developer Dashboard** | `http://localhost/dashboard` | `https://dashboard.[YOUR DOMAIN]/` | Operators/developers — monitoring & ops |
| **Seller Portal** | `http://localhost/seller/login` | `https://sales.[YOUR DOMAIN]/` | Sellers — manage a store |
| **Admin Portal** | `http://localhost/admin` | `https://admin.[YOUR DOMAIN]/` | Administrators — platform governance |

> `[YOUR DOMAIN]` is the apex you bring yourself (`ROOT_DOMAIN`). The `sales.` / `admin.` / `dashboard.` subdomains are derived from it automatically by Terraform.

---

### 🛒 Mockten storefront

The buyer-facing shop. Sign in at `/user/login` (or via Google/Facebook SSO — see [Authentication](#authentication-setup)).
<img width="2006" height="912" alt="SUPER SALE" src="https://github.com/user-attachments/assets/d2766e2c-6f27-430d-9bb0-be5ac9a082dd" />

Full catalog, MeiliSearch full-text search, Redis-backed cart, Stripe (test-mode) checkout, distance-based shipping via the `geocoding` service, order history, reviews, and personalized recommendations. See the [mockten storefront docs](https://github.com/mockten/mockten#-mockten-storefront--httplocalhost) for the buyer flow and the Stripe test cards.

<img width="1440" alt="Mockten storefront" src="https://github.com/user-attachments/assets/2bbd4a97-a5c7-47cf-99f2-168162273272" />

---

### 📊 Developer Dashboard

A real-time internal portal for monitoring and operating the platform.

| Panel | Description |
|-------|-------------|
| **Dashboard** | Running containers, CPU/memory charts, Kong API telemetry, MySQL/Redis stats, top & slowest endpoints. |
| **Container List** | All workloads with status/uptime/resources. |
| **Log Viewer** | Live container logs with filtering and search. |
| **DB Viewer** | Browse MySQL tables with row-level CRUD. |
| **Topology** | Visual graph of the microservice architecture and data flow. |
| **API Specifications** | Every Kong route rendered with Description (EN/JA/ZH), Input/Response Schema, and a working **Test Request** form. |
| **Access Management** | Keycloak realm config: clients, roles, identity providers. |
| **Model Performance** | Recommendation model metadata and metrics (Precision@K, Recall@K, NDCG, AUC, MRR, Hit Rate, Coverage). |
| **Data Pipeline** | Triggers and monitors the Airflow ETL DAG. |

> On a Kubernetes deployment (local k8s + cloud) the Dashboard shows a **`K8S`** badge and the deployed version; in mockten's own dev-compose it runs in DEV mode instead.

<img width="2982" height="1492" alt="CleanShot 2026-07-24 at 10 43 24@2x" src="https://github.com/user-attachments/assets/73da13b6-b60c-47cc-9d85-e0ec9fbbb6cd" />


---

### 🏪 Seller Portal

Where sellers manage their store, all backed by live data.

- **Auth**: sign-up creates a Keycloak user in the **Seller** group; sign-in verifies the `seller` role. New sellers start **pending** until an administrator approves them.
- **Overview**: Total Revenue / Orders / Products Sold / Customers with month-over-month change, plus Recent Orders.
- **Products**: paginated list with status labels, Add/Edit product with up to 3 MinIO images, activate/deactivate.
- **Orders / Settings**: orders containing the seller's products; edit Store Name and the storefront "About the Vendor" description.

<img width="2400" alt="Seller Portal overview" src="https://github.com/user-attachments/assets/5cecc765-8379-4eee-91cc-c3e8a57b97a6" />

---

### 🛡️ Admin Portal

Platform governance for administrators, backed by live Keycloak and backend data. Sign in with an administrator account (e.g. `superadmin` / `superadmin` in local dev).

- **User Management**: All / Active / Pending / Suspended filters; create, edit, approve pending sellers, suspend, delete.
- **Order Monitoring**: *flagged* orders with a derived reason (failed/canceled, unusual location, rapid orders, high value).
- **System Health**: live component health and System Alerts from real backend metrics.
- **Activity Logs**: platform-wide audit trail, paginated.

<img width="2308" height="1156" alt="Admin Portal" src="https://github.com/user-attachments/assets/cdabae6a-223e-4c8c-98fe-2837c37bd92f" />

---

## Architecture
<img width="2040" height="1120" alt="CleanShot 2026-07-24 at 10 40 02@2x" src="https://github.com/user-attachments/assets/6ff4afca-a999-444a-8358-82389f0b41a6" />


### Services

| Module | Language / Tech | Responsibility |
|--------|-----------------|----------------|
| `ecfront` | React + Vite + TypeScript | Storefront SPA plus the Seller and Admin portals |
| `apigw` | Kong | API gateway — routing, auth plugins, rate limiting |
| `uam` | Keycloak | User Account Management: buyers, sellers, admins, social login |
| `product` | Go (Gin) | Product catalog: listing, detail, reviews, wishlist |
| `searchitem` | Go | Product search backed by Meilisearch |
| `cart` | Go + Redis | Shopping cart service |
| `sale` | Go | Orders / sales, plus the admin monitoring & audit APIs |
| `ecpay` | Go (Gin) | Payment processing (Stripe) |
| `shipment` | Go | Shipment / delivery |
| `ranking` | Go | Product ranking |
| `recommendation` | Python (FastAPI + LightFM) | Personalized recommendations |
| `geocoding` | Go | Address geocoding (Nominatim) |
| `sync` | Bash / cron | Incremental MySQL → Meilisearch index sync |
| `airflow` | Python (Apache Airflow) | Bronze→Silver→Gold ETL pipeline + model training |
| `mysql` | MySQL | Primary relational datastore + schema/seed |
| `redis` | Redis | Cache / cart backing store |
| `meilisearch` | Meilisearch | Full-text search engine |
| `minIO` | MinIO | S3-compatible object storage (product images, ML models) |
| `monitoring` | Node dashboard | The Developer Dashboard |

All of these are packaged as reusable modules under [`common/k8s`](common/k8s) and deployed identically by each cloud/local root.

---

## How this repo works

Terraform roots, one per target — all consuming the same `common/k8s` module:

| Root | Target | State |
|------|--------|-------|
| [`local`](local) | local Kubernetes (docker-desktop) | local state |
| [`gcp`](gcp) | GKE — **the reference implementation** ([gcp/README.md](gcp/README.md)) | GCS backend |
| [`aws`](aws) | EKS — **cloud-native (ALB / ACM / CloudFront)** ([aws/README.md](aws/README.md)) | S3 backend |
| [`azure`](azure) | AKS ([azure/README.md](azure/README.md)) | Azure Storage backend |

**Configuration comes only from `TF_VAR_*` environment variables — never a committed `tfvars`.** Locally they are exported from the gitignored `.env` (copy [`.env.example`](.env.example)); in CI they come from GitHub secrets. The variable names are identical everywhere, so the same `terraform apply` runs in both. See [gcp/README.md](gcp/README.md#github-actions-secrets) for the full secret list and the `.env` → GitHub-secret name mapping.

### CI / CD

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **DryRun(minikube)** | push (automatic) | `terraform plan` for the local root — no cloud account needed |
| **DryRun(GCP / AWS / Azure)** | manual | `init` → `validate` → `plan` against each cloud root |
| **Deploy(GCP / AWS / Azure)** | manual | `terraform apply` — brings the platform up |
| **Destroy(GCP / AWS / Azure)** | manual (types a confirm value) | `terraform destroy` — tears it down |

Only the lightweight local plan runs automatically on push; every cloud `apply`/`destroy` is a deliberate manual button, so a destroy is never one mis-click from an apply, and a clone without cloud secrets never fails on every push.

### GitHub Actions secrets

CI reads everything from repository secrets (**Settings → Secrets and variables → Actions**). The values are the same ones your local `.env` holds; only the source differs. Two things to watch when you copy them over:

- The GitHub credentials are **renamed** `GITHUB_*` → `GH_*`.
- For OAuth, CI only ever needs the **cloud** app: the workflows resolve `CLOUD_GOOGLE_CLIENT_ID || GOOGLE_CLIENT_ID`, and the only job that reads the bare `GOOGLE_CLIENT_ID` is `DryRun(minikube)`, which just plans and never exercises the value. So set the cloud app under `CLOUD_GOOGLE_*` / `CLOUD_FACEBOOK_*`; the dev/localhost OAuth app belongs in each developer's `.env`, not here.

**Where each cloud's full setup is documented** — start here for the cloud you target:

| Cloud | Setup doc |
|-------|-----------|
| **GCP** | [**gcp/README.md**](gcp/README.md#github-actions-secrets) — one-time prerequisites and the exact GCP secret list, including how to create the `GCP_SA_KEY` service-account key |
| **AWS** | [**aws/README.md**](aws/README.md#github-actions-secrets) — one-time prerequisites (S3 state bucket, DynamoDB lock, deploy IAM user) and the `AWS_*` secrets |
| **Azure** | [**azure/README.md**](azure/README.md) — one-time prerequisites (service principal, tfstate storage, provider registration) and the `AZURE_*` secrets |

The tables below are the quick reference; the per-cloud docs above have the step-by-step.

**Shared — needed by every cloud (GCP / AWS / Azure):**

| Secret | Source (`.env`) | What it is |
|--------|-----------------|------------|
| `GH_USERNAME` / `GH_TOKEN` / `GH_EMAIL` | `GITHUB_USERNAME` / `GITHUB_TOKEN` / `GITHUB_EMAIL` | ghcr.io image pull (**renamed**) |
| `ROOT_DOMAIN` | `ROOT_DOMAIN` | apex domain served by the storefront, e.g. `example.dpdns.org` |
| `LETSENCRYPT_EMAIL` | `LETSENCRYPT_EMAIL` | ACME account email for cert expiry notices (**GCP / Azure only** — AWS issues TLS from ACM) |
| `ALLOWLIST_CIDR` | `ALLOWLIST_CIDR` | IP(s) allowed at the ingress + control plane; **comma-separated** for several people, e.g. `1.2.3.4/32,5.6.7.8/32` |
| `DOMAIN_API_KEY` | `DOMAIN_API_KEY` | registrar (DigitalPlat) token used to push nameserver delegation |
| `STRIPE_SECRET_KEY` / `STRIPE_PUBLIC_KEY` | same | Stripe test-mode keys for payments |
| `CLOUD_GOOGLE_CLIENT_ID` / `CLOUD_GOOGLE_CLIENT_SECRET` | same | **cloud** Google OAuth app (redirect URI `https://${ROOT_DOMAIN}/...`) |
| `CLOUD_FACEBOOK_CLIENT_ID` / `CLOUD_FACEBOOK_CLIENT_SECRET` | same | optional — omit to reuse the dev Facebook app |

**GCP — `Deploy/DryRun/Destroy (GCP)`:**

| Secret | What it is |
|--------|------------|
| `GCP_SA_KEY` | full JSON key of the deploy service account (see [gcp/README.md](gcp/README.md#github-actions-secrets), Prerequisites step 5) |
| `GCP_PROJECT` | GCP project id (also names the `${project}-tfstate` bucket) |

**AWS — `AWS 1/2/3`:**

| Secret | What it is |
|--------|------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | deploy IAM user (or switch the workflow to an OIDC role) |
| `AWS_REGION` | e.g. `ap-northeast-1` (must match the tfstate bucket's region) |
| `AWS_TFSTATE_BUCKET` | S3 bucket holding Terraform state (`mockten-tfstate-<account-id>`) |

AWS does **not** use `LETSENCRYPT_EMAIL` (it issues TLS from ACM), and it needs no
`GCP_SA_KEY` / `AZURE_*`. See [aws/README.md](aws/README.md#github-actions-secrets) for the
`gh secret set` commands and the one-time backend/IAM prerequisites.

**Azure — `Azure 1/2/3`:**

| Secret | What it is |
|--------|------------|
| `AZURE_CLIENT_ID` / `AZURE_CLIENT_SECRET` / `AZURE_SUBSCRIPTION_ID` / `AZURE_TENANT_ID` | deploy service-principal credentials (mapped to `ARM_*`) |

You only need the block for the cloud you actually deploy to. `DryRun(minikube)` needs just the shared app secrets (it plans the local root); the GCP/AWS/Azure blocks are read only by their own workflows.

---

## Running locally (local Kubernetes)

Requires a running **docker-desktop** Kubernetes cluster, `terraform`, `kubectl`, and [`gotask`](https://taskfile.dev). Configuration is read from `.env`.

```sh
cp .env.example .env      # then fill in your values (see .env.example)
task setup                # fetch product photos
task build                # terraform apply against the docker-desktop cluster
```

Open the storefront at `http://localhost/user/login`; the other surfaces are at `/dashboard`, `/seller/login`, and `/admin/login`.

- **/user/login**
  <img width="1344" height="1412" alt="user login" src="https://github.com/user-attachments/assets/e2f004c4-aedb-4bde-9213-9bbda96eabba" />
- **/dashboard**
　 <img width="2982" height="1492" alt="CleanShot 2026-07-24 at 10 43 24@2x" src="https://github.com/user-attachments/assets/73da13b6-b60c-47cc-9d85-e0ec9fbbb6cd" />
- **/seller/login**
  <img width="1232" height="1270" alt="seller login" src="https://github.com/user-attachments/assets/172280c5-2a26-4262-9240-90f89e91c9cc" />
- **/admin/login**
  <img width="1006" height="1220" alt="admin login" src="https://github.com/user-attachments/assets/f7ebbf69-2199-4c2a-9b82-fef818d46967" />

Tear it down with `task destroy`.

## Deploying to a cloud

The reference target is **GKE**. See **[gcp/README.md](gcp/README.md)** for the one-time prerequisites (project, APIs, state bucket, domain, deploy service-account key) and the exact secret list, then run the **Deploy(GCP)** workflow from the Actions tab. **Azure** ([azure/README.md](azure/README.md)) and **AWS** ([aws/README.md](aws/README.md)) follow the same shape — Azure mirrors GCP (ingress-nginx + cert-manager), while AWS is cloud-native (ALB + ACM + CloudFront/WAF).

After apply, Terraform pushes the nameserver delegation to your registrar and TLS is issued automatically — Let's Encrypt via cert-manager on GCP/Azure, ACM on AWS. Access is locked to `ALLOWLIST_CIDR` (the ingress/API server on GCP/Azure; the CloudFront WAF + EKS API on AWS).

---

## Authentication setup

To enable Google / Facebook sign-in, create OAuth apps and register the redirect URIs. Because mockten runs both locally and in the cloud, register **both** URIs on the app you use:

| Provider | Local redirect URI | Cloud redirect URI |
|----------|--------------------|--------------------|
| Google | `http://localhost/api/uam/broker/google/endpoint` | `https://[YOUR DOMAIN]/api/uam/broker/google/endpoint` |
| Facebook | `http://localhost/api/uam/broker/facebook/endpoint` | `https://[YOUR DOMAIN]/api/uam/broker/facebook/endpoint` |

<img width="1594" height="1292" alt="Google OAuth client" src="https://github.com/user-attachments/assets/0769cb4f-53b3-4558-be68-53ddffb899ce" />

Put the **dev** app credentials in `.env` (`GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`, `FACEBOOK_*`) for local. For a cloud deployment you may use a **separate** OAuth app so a leaked dev secret can't be used against production — set `CLOUD_GOOGLE_*` / `CLOUD_FACEBOOK_*`; if unset, the dev app is reused. In CI, only the cloud app values are needed (see [gcp/README.md](gcp/README.md#github-actions-secrets)).

## Payment (Stripe) setup

Card payments use [Stripe](https://stripe.com/) in **test mode**. From **Developers → API keys**, copy the **Publishable** (`pk_test_…`) and **Secret** (`sk_test_…`) keys into `.env` as `STRIPE_PUBLIC_KEY` / `STRIPE_SECRET_KEY`. `.env` is gitignored, so keys stay local; in CI they come from GitHub secrets.

<img width="1642" height="736" alt="Stripe keys" src="https://github.com/user-attachments/assets/d458bd0d-8046-4427-a2ae-440ad1acb9ce" />

The `ecfront` image is environment-agnostic — no key is baked in. Terraform injects `STRIPE_PUBLIC_KEY` into the container from the environment at deploy time (rendered into `/config.js` at container start), so the same image promotes from local to cloud unchanged. Use test cards such as `4242 4242 4242 4242` — no real money moves.

---

## Requirements

| Tool | Version | For |
|------|---------|-----|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | 1.9.5 | every root |
| [gotask](https://taskfile.dev/#/installation) | latest | the local `task` runner |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | latest | talking to the cluster |
| Docker Desktop (Kubernetes enabled) | 24+ | the local cluster |
| [gcloud](https://cloud.google.com/sdk/docs/install) / [aws](https://aws.amazon.com/cli/) / [az](https://learn.microsoft.com/cli/azure/install-azure-cli) | latest | the cloud you target |
