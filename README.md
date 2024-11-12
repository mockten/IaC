[![DryRun(minikube)](https://github.com/mockten/IaC/actions/workflows/dry-run-local.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/dry-run-local.yml)
[![DryRun(Azure)](https://github.com/mockten/IaC/actions/workflows/dry-run-azure.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/dry-run-azure.yml)
# Building Infrastructure

## For AWS/GCP/Azure
To build infrastructure on AWS, GCP, or Azure, use GitHub Actions.

## For Local Environment
Before proceeding, ensure you have the following tools installed on your system:

- [Terraform](https://www.terraform.io/downloads.html)
- [gotask](https://taskfile.dev/#/installation)

## Verify Installation

To confirm that both `terraform` and `gotask` are correctly installed, run the following commands:

```sh
terraform -v
task -v
```

To build infrastructure locally, follow these steps:

1. Create a `local.tfvars` file in the `local` directory with the following content:

    ```hcl
    github_username = "GITHUB_USERNAME"
    github_token    = "GITHUB_TOKEN"
    github_email    = "GIT_HUB_EMAIL"
    ```
2. To init k8s in your local environment, please execute the following commands:

    ```sh
    task init
    ```
3. To build k8s in your local environment, please execute the following commands:

    ```sh
    task build
    ```
4. To clean up, please execute the following commands:

    ```sh
    task destroy
    ```
