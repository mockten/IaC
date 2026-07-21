provider "kubernetes" {
  config_path = "~/.kube/config"
  # Pin the context. Without this the provider follows whatever kubectl context
  # happens to be current, so running `task destroy` while pointed at a cloud
  # cluster would execute this root's state against THAT cluster. The kubeconfig
  # on this machine carries GKE, EKS and colima contexts, so that is a live
  # hazard, not a theoretical one. `local` must only ever touch docker-desktop.
  #
  # Defaults to docker-desktop so the safety property holds for every developer.
  # CI overrides it (TF_VAR_kube_context=minikube) to plan against the minikube
  # cluster the DryRun(minikube) workflow starts — the only sanctioned override.
  config_context = var.kube_context
}

module "local" {
  source = "./k8s"
}

module "common_k8s" {
  source                 = "../common/k8s"
  github_username        = var.github_username
  github_token           = var.github_token
  github_email           = var.github_email
  google_client_id       = var.google_client_id
  google_client_secret   = var.google_client_secret
  facebook_client_id     = var.facebook_client_id
  facebook_client_secret = var.facebook_client_secret
  stripe_secret_key      = var.stripe_secret_key
  stripe_public_key      = var.stripe_public_key
  depends_on             = [module.local]
}
