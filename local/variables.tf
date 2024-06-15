variable "github_username" {
  description = "GitHub username"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_email" {
  description = "GitHub email"
  type        = string
}
