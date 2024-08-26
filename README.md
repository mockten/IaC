[![DryRun(minikube)](https://github.com/mockten/IaC/actions/workflows/basic-plan.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/basic-plan.yml)
# Building Infrastructure

## For AWS/GCP/Azure
To build infrastructure on AWS, GCP, or Azure, use GitHub Actions.

## For Local Environment
To build infrastructure locally, follow these steps:

1. Create a `local.tfvars` file in the `local` directory with the following content:

    ```hcl
    github_username = "GITHUB_USERNAME"
    github_token    = "GITHUB_TOKEN"
    github_email    = "GIT_HUB_EMAIL"
    ```

2. Execute the following commands:

    ```sh
    cd local
    terraform apply -var-file="local.tfvars"
    ```