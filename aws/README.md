# mockten on EKS

Terraform for the mockten platform on **Amazon Elastic Kubernetes Service (EKS)** — the
AWS sibling of [`gcp/`](../gcp) and [`azure/`](../azure). Unlike those two, which run
ingress-nginx + cert-manager everywhere for parity, **AWS is deliberately cloud-native**:
the **AWS Load Balancer Controller + a single ALB** (shared by the four host Ingresses via
an IngressGroup), **ACM** for TLS, and **CloudFront + WAF** in front for edge caching and
IP restriction. It also stands up a VPC (public + private subnets across two AZs, one NAT
gateway), the EKS cluster + managed node group, a Route53 hosted zone with automatic
nameserver delegation, and the portable `common/k8s` workloads — the same module GKE and
AKS deploy.

One `terraform apply` from an empty account builds everything and the dashboard reads
all-READY. It runs from CI via **AWS 2.Deploy** (manual) and is torn down by
**AWS 3.Destroy** (manual). `terraform apply` is idempotent: if a run fails partway,
run it again and it continues from where it stopped.

> Each concern is a module, applied in this order (the order matters — see the traps
> below): [`nw/`](nw) (VPC) → [`eks/`](eks) (cluster + IRSA + EBS CSI) → [`dns/`](dns)
> (zone + delegation) → [`platform/`](platform) (Load Balancer Controller + ACM cert) →
> `common/k8s` (workloads) → [`routing/`](routing) (the ALB Ingresses) → [`cdn/`](cdn)
> (CloudFront + WAF + the A records, which alias CloudFront, not the ALB).

## Prerequisites (one-time, per fresh clone / account)

Run these once with the AWS CLI before the first `terraform init`. They create only the
remote-state backend; everything else (VPC, cluster, DNS zone, cluster resources) is
Terraform-managed.

```sh
REGION=ap-northeast-1        # must match providers.tf's backend `region`

# 1. Confirm you are pointed at the intended account (the free-tier test account,
#    NOT your everyday one). The bucket name embeds this id, so S3's global namespace
#    never collides with another account's state bucket.
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "using account: $ACCOUNT_ID"
BUCKET="mockten-tfstate-${ACCOUNT_ID}"

# 2. Remote state: a versioned, encrypted S3 bucket + a DynamoDB lock table. The
#    backend config in providers.tf is hardcoded to this region, this key, and the
#    table name "mockten-tflock" — only the bucket name is supplied at init time
#    (it is per-account). Change the literals in providers.tf if you use others.
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws dynamodb create-table --table-name mockten-tflock --region "$REGION" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST

# 3. Deploy IAM user. Its access key becomes the AWS_* values in .env / GitHub secrets.
#    AdministratorAccess keeps EKS/IRSA/Route53/CloudFront/WAF role creation from tripping
#    over permissions on a throwaway account; scope it tighter if you prefer least-privilege.
aws iam create-user --user-name mockten-deployer
aws iam attach-user-policy --user-name mockten-deployer \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam create-access-key --user-name mockten-deployer
#    Map the output: AccessKeyId -> AWS_ACCESS_KEY_ID, SecretAccessKey -> AWS_SECRET_ACCESS_KEY.
```

> **Account isolation.** These credentials are read as `AWS_*` environment variables, so
> they only apply in a shell that has sourced `.env`. A plain `aws` in another terminal
> keeps using `~/.aws` (your default profile) and is never touched. `AWS_EXPECTED_ACCOUNT_ID`
> in `.env` is the free-tier account id; assert it before any run with
> `aws sts get-caller-identity`.

## Configuration

Terraform reads everything from `TF_VAR_*` (never a committed tfvars), and the AWS SDK
reads `AWS_*` for credentials. Locally the repo `.env` (gitignored) supplies them; in CI
they come from GitHub secrets. AWS uses ACM for TLS, so there is **no** `LETSENCRYPT_EMAIL`
or `acme_staging` (unlike gcp/azure).

| Variable | Notes |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | the deploy IAM user (step 3) |
| `AWS_DEFAULT_REGION` / `TF_VAR_region` | deploy region (e.g. `ap-northeast-1`) |
| `AWS_TFSTATE_BUCKET` | the state bucket from step 2 (`mockten-tfstate-<account-id>`) |
| `github_username` / `github_token` / `github_email` | ghcr image pull |
| `google_client_id` / `google_client_secret` / `facebook_*` | Keycloak SSO |
| `stripe_secret_key` / `stripe_public_key` | payments |
| `domain_api_key` | DigitalPlat bearer token for the nameserver push |
| `allowlist_cidr` | CIDR(s) allowed at the CloudFront WAF + the EKS API server; comma-separated for several people |
| `root_domain` | apex domain served by the storefront |

The shared secret list (with the `GITHUB_* -> GH_*` rename and the cloud-vs-dev OAuth
guidance) is in the top-level [README](../README.md#github-actions-secrets). AWS needs
**only the `AWS_*` secrets in addition** to that shared set — no `GCP_SA_KEY`, no `AZURE_*`,
and (because it uses ACM) no `LETSENCRYPT_EMAIL`.

## GitHub Actions secrets

CI (`AWS 1/2/3`) reads everything from repository secrets. The whole 0→1→0 cycle then runs
from the Actions tab with no laptop involved. Set them once with `gh` from a shell that has
sourced your populated `.env` (values never leave your machine except into GitHub's secret
store):

```sh
# from the repo root, with .env filled in and the free-tier account selected
set -a; . ./.env; set +a
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# AWS-specific
gh secret set AWS_ACCESS_KEY_ID     --body "$AWS_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
gh secret set AWS_REGION            --body "$AWS_DEFAULT_REGION"
gh secret set AWS_TFSTATE_BUCKET    --body "mockten-tfstate-${ACCOUNT_ID}"

# Shared app secrets (GITHUB_* is renamed to GH_*)
gh secret set GH_USERNAME             --body "$GITHUB_USERNAME"
gh secret set GH_TOKEN                --body "$GITHUB_TOKEN"
gh secret set GH_EMAIL                --body "$GITHUB_EMAIL"
gh secret set ROOT_DOMAIN             --body "your-registered-domain.example.org"
gh secret set ALLOWLIST_CIDR          --body "$ALLOWLIST_CIDR"
gh secret set DOMAIN_API_KEY          --body "$DOMAIN_API_KEY"
gh secret set STRIPE_SECRET_KEY       --body "$STRIPE_SECRET_KEY"
gh secret set STRIPE_PUBLIC_KEY       --body "$STRIPE_PUBLIC_KEY"
gh secret set CLOUD_GOOGLE_CLIENT_ID     --body "${CLOUD_GOOGLE_CLIENT_ID:-$GOOGLE_CLIENT_ID}"
gh secret set CLOUD_GOOGLE_CLIENT_SECRET --body "${CLOUD_GOOGLE_CLIENT_SECRET:-$GOOGLE_CLIENT_SECRET}"
# Facebook is optional — set CLOUD_FACEBOOK_* only if you use it.
```

`ROOT_DOMAIN` is your own registered domain (it is not stored in the repo); set it to the
apex the storefront serves. AWS does **not** take `LETSENCRYPT_EMAIL`.

## Apply

```sh
cd aws
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
terraform init -backend-config="bucket=mockten-tfstate-${ACCOUNT_ID}"
terraform apply
```

Or run **AWS 2.Deploy** from the Actions tab. During apply Terraform pushes the nameserver
delegation to the registrar, ACM validates the certificates in the Route53 zone, the Load
Balancer Controller provisions the ALB, and CloudFront fronts it. End users reach the site
only through CloudFront, which its **WAF restricts to `ALLOWLIST_CIDR`** (plus the cluster's
NAT egress so the dashboard's own readiness check passes); the ALB itself accepts traffic
only from CloudFront's edges. The EKS API server is likewise locked to `ALLOWLIST_CIDR`.

## Teardown

Run **AWS 3.Destroy** (type the account id to confirm), or `terraform destroy` locally.
Destroy deletes everything Terraform manages **plus** the billing resources the Load
Balancer Controller creates out-of-band (the ALB, its target groups and security group) and
any orphaned CSI-provisioned EBS volumes, so nothing keeps costing afterward. The
`mockten-tfstate-*` bucket and the `mockten-tflock` table are intentionally preserved.
`keep_dns_zone: true` keeps the Route53 zone + delegation to skip re-delegation on the next
apply. Deleting the CloudFront distribution takes ~15 min (it is disabled, then removed) —
that is normal.

**For a repeated 0→1→0 cycle, destroy with `keep_dns_zone: true`.** A hosted zone is ~\$0.50/mo
(not a compute cost), and keeping it means the next Deploy reuses the same nameservers, so
**ACM validation completes in seconds** instead of waiting for a fresh registrar delegation
to propagate (which can take many minutes and, if slow, times the apply out). A full wipe
including the zone is fine too — just expect the first redeploy's ACM step to wait on
propagation.

## EKS / free-tier gotchas

The AWS free tier does **not** cover EKS, NAT, or the ALB — the control plane (~\$0.10/h),
the NAT gateway, and the ALB bill from the first hour. CloudFront's free tier (1 TB + 10M
requests/mo) covers a demo; the WAF WebACL is a few \$/mo (well within a new-account
credit). Keep environments short-lived and destroy promptly.

- **Free-tier accounts block paid instance types.** A new AWS Free-plan account refuses
  non free-tier-eligible EC2 types ("InvalidParameterCombination: not eligible for Free
  Tier"). The node group uses `m7i-flex.large` (2 vCPU / 8 GiB, free-tier-eligible) × 2 —
  the D2s_v7 × 2 equivalent — for this reason.
- **EBS CSI needs its own IRSA role.** Managed nodes launch with IMDS hop limit 1, so the
  CSI controller pod can't reach IMDS and the addon hangs in CREATING. It is given a
  dedicated OIDC-trust role for `kube-system:ebs-csi-controller-sa` (passing the node role
  fails — its trust is ec2, not web-identity). The `gp3` StorageClass lives at the root
  (`main.tf`), not in `eks/`: a kubernetes-provider resource inside the module that
  configures that provider would be a cycle.
- **Module ordering is load-bearing.** The Load Balancer Controller's admission webhook
  intercepts every Service, so `common_k8s` must wait for `platform` (controller Ready);
  and the ALB Ingresses build a target group per backend Service, so `routing` must wait
  for `common_k8s`. Reading the ALB back for CloudFront's origin uses a `time_sleep` then
  `data.aws_lb` (tag `ingress.k8s.aws/stack = mockten`).
- **CloudFront reaches the ALB over HTTP.** Going HTTPS to the origin would make CloudFront
  validate the ALB's cert against the ALB's own `*.elb` hostname (which the mockten cert
  does not cover) → 502. TLS is terminated at CloudFront (a us-east-1 ACM cert — CloudFront
  requires us-east-1); the hop is private (the ALB security group allows only CloudFront's
  origin-facing managed prefix list, on port 80 only to stay under the 60-rules-per-SG
  limit).
- **Kubernetes version** (`kubernetes_version`, default `1.31`) is pinned: an unpinned
  version silently upgrades the control plane on re-apply.
