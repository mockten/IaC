resource "kubernetes_secret" "ghcr" {
  metadata {
    name = "ghcr-secret"
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      "auths" = {
        "https://ghcr.io" = {
          "auth" :  base64encode("${var.github_username}:${var.github_token}")
        }
      }
    })
  }
}

module "ecfront" {
  source = "./ecfront"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}

module "uam" {
  source = "./uam"
  secret_name = kubernetes_secret.ghcr.metadata[0].name
}