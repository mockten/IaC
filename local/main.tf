provider "kubernetes" {
  config_path = "~/.kube/config"
}

module "local" {
  source    = "./k8s"
}

module "common_k8s" {
  source    = "../common/k8s"
  github_username = var.github_username
  github_token    = var.github_token
  github_email    = var.github_email
  depends_on = [module.local]
}
