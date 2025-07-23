[![DryRun(minikube)](https://github.com/mockten/IaC/actions/workflows/dry-run-local.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/dry-run-local.yml)
[![DryRun(Azure)](https://github.com/mockten/IaC/actions/workflows/dry-run-azure.yml/badge.svg)](https://github.com/mockten/IaC/actions/workflows/dry-run-azure.yml)
# Building Infrastructure

## For AWS/GCP/Azure
To build infrastructure on AWS, GCP, or Azure, use GitHub Actions.

## For Local Environment
Before proceeding, ensure you have the following tools installed on your system:

- [Terraform](https://www.terraform.io/downloads.html)
- [gotask](https://taskfile.dev/#/installation)

## Google Authentication Setup
To use Goole SignUp/SignIn, please create Google auth client like below.
<img width="1594" height="1292" alt="CleanShot 2025-07-22 at 13 16 15@2x" src="https://github.com/user-attachments/assets/0769cb4f-53b3-4558-be68-53ddffb899ce" />
| Setting                   | Value                                                |
|---------------------------|------------------------------------------------------|
| Application type          | Web application                                    |
| Authorized Redirect URIs | http://localhost/api/uam/broker/google/endpoint     |

Once you get Client ID/secret, please replace the value in common/k8s/uam/config.json
<img width="1098" height="492" alt="CleanShot 2025-07-23 at 21 47 39@2x" src="https://github.com/user-attachments/assets/b417cfc0-266c-4312-9e05-e84624c900dc" />



## Facebook Authentication Setup
To use Facebook SignUp/SignIn, please create App in [Facebook Developer](https://developers.facebook.com/apps/)
<img width="2016" height="754" alt="CleanShot 2025-07-22 at 16 38 38@2x" src="https://github.com/user-attachments/assets/b4b95c3b-b75d-4a2e-bf05-464df6c0c09e" />
Once you get App ID/secret, please replace the value in common/k8s/uam/config.json
<img width="1108" height="516" alt="CleanShot 2025-07-23 at 21 48 26@2x" src="https://github.com/user-attachments/assets/75d1ebb7-8bae-401c-a429-773bf6aa0b67" />


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
6. (For GitHub Codespace User) Please open a new terminal and execute the following commands:

    ```sh
    task codespsace_portforward
    ```
    ![CleanShot 2024-12-15 at 03 55 34](https://github.com/user-attachments/assets/5f47db75-dac4-4dda-a025-867b92d799e5)

7. To clean up, please execute the following commands:

    ```sh
    task destroy
    ```
8. (For Non GitHub Codespace User) you can access to mockten app with "http://localhost"
9. (For GitHub Codespace User) you can access to mockten app using forward for "http://localhost:8080"
![CleanShot 2024-12-15 at 03 57 35](https://github.com/user-attachments/assets/2fd67a5f-15e6-42b0-ad4d-5aad6a313725)
![CleanShot 2024-12-15 at 03 58 09](https://github.com/user-attachments/assets/b0eaf223-9943-4853-b159-8833718547ba)


