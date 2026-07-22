variable "image" {
  description = "One-shot behavior-seeder image published by mockten (e.g. ghcr.io/mockten/seeder:latest). Runs behavior_seeder.py against in-cluster mysql/apigw."
  type        = string
}
