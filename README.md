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
1. (For GitHub Codespace User) Open your GitHub Cordspace User
2. (For GitHub Codespace User) please execute the following commands:

    ```sh
    task codespace_k8s_setup
    ```
    ![CleanShot 2024-12-15 at 03 39 27](https://github.com/user-attachments/assets/32a5c9a1-15cd-432d-bc92-5e21cd3e81da)


3. Create a `local.tfvars` file in the `local` directory with the following content:

    ```hcl
    github_username = "GITHUB_USERNAME"
    github_token    = "GITHUB_TOKEN"
    github_email    = "GIT_HUB_EMAIL"
    ```
4. To init k8s in your local environment, please execute the following commands:

    ```sh
    task init
    ```
5. To build k8s in your local environment, please execute the following commands:

    ```sh
    task build
    ```
6. (For GitHub Codespace User) please open a new terminal and execute the following commands:

    ```sh
    task codespsace_portforward
    ```
7. To clean up, please execute the following commands:

    ```sh
    task destroy
    ```
8. (For Non GitHub Codespace User) you can access to mockten app with "http://localhost"
9. (For GitHub Codespace User) you can access to mockten app using forward for "http://localhost:8080"
