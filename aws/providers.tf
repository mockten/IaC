# DRAFT — never applied. Mirrors gcp/ so the same common/k8s module runs on EKS.
# Written before an AWS account existed; expect to fix small things on first apply.
terraform {
  required_version = ">= 1.9.0"

  # Same shape as gcp's GCS backend. Create the bucket and the lock table before
  # the first init:
  #   aws s3api create-bucket --bucket <project>-tfstate --region <region> \
  #     --create-bucket-configuration LocationConstraint=<region>
  #   aws dynamodb create-table --table-name <project>-tflock \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST
  backend "s3" {
    key            = "mockten/terraform.tfstate"
    region         = "ap-northeast-1" # must match the region the tfstate bucket lives in
    encrypt        = true
    dynamodb_table = "mockten-tflock"
    # bucket supplied by -backend-config="bucket=mockten-tfstate-<account-id>"
    # (see README — the bucket name is per-account because S3 names are global).
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    # PATCHes the registrar's nameservers over its REST API (no official provider).
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "~> 1.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # The platform module waits out the ALB provisioning gap with time_sleep.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      project   = "mockten"
      managedBy = "terraform"
    }
  }
}

# CloudFront-scoped resources (the viewer ACM certificate and the WAFv2 WebACL)
# must live in us-east-1 regardless of where the rest of the stack runs.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      project   = "mockten"
      managedBy = "terraform"
    }
  }
}

# EKS auth tokens expire in 15 minutes. Reading them through data sources (rather
# than exec plugins) keeps a long apply from failing halfway with a 401, which is
# the usual first-run surprise on EKS.
# `name` already orders this after the cluster exists. A broad
# `depends_on = [module.eks]` would instead tie it to the module's close node —
# and because the gp3 StorageClass (a kubernetes-provider resource) lives in that
# module, that provider would depend on a data source that depends on the whole
# module, which is a cycle. The StorageClass is created at the root instead (see
# main.tf) so module.eks stays pure-AWS.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}
