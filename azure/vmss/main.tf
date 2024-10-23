resource "azurerm_virtual_machine_scale_set" "mockten_vmss" {
  name                = "mockten-vmss"
  location            = var.location
  resource_group_name = var.resource_group_name
  #depends_on = [
  #  module.nw.mockten_vnet
  #]
  sku {
    name     = var.vmss_sku
    tier     = var.vmss_tier
    capacity = var.vmss_capacity
  }
  
  upgrade_policy_mode = "Manual"

  network_profile {
    name    = "mockten-network-profile"
    primary = true
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = var.mockten_pri_subnet1
    }
  }

  os_profile {
    computer_name_prefix = "vmss"
    admin_username       = var.admin_username
    admin_password       = var.admin_password
    custom_data          = base64encode(<<EOT
#!/bin/bash
sudo apt update
sudo apt install jq -y
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
echo "export GITHUB_PAT=${var.repo_pat}" >> /etc/environment
#RUNNER_ID=$(curl -s -X GET -H "Authorization: token $GITHUB_PAT" https://api.github.com/repos/mockten/IaC/actions/runners | jq -r '.runners[] | select(.name == "$(hostname)") | .id')
#if [ -n "$RUNNER_ID" ]; then
#    curl -X DELETE -H "Authorization: token $GITHUB_PAT" https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runners/$RUNNER_ID
#fi
RUNNER_NAME="mockten-vmss$(date +'%Y%m%d%H%M')"
REG_TOKEN=$(curl -s -X POST -H "Authorization: token $GITHUB_PAT" https://api.github.com/repos/mockten/IaC/actions/runners/registration-token | jq -r .token)
curl -o actions-runner-linux-x64-2.298.2.tar.gz -L https://github.com/actions/runner/releases/download/v2.298.2/actions-runner-linux-x64-2.298.2.tar.gz
tar xzf ./actions-runner-linux-x64-2.298.2.tar.gz
echo "" | ./config.sh --url https://github.com/mockten/IaC --token $REG_TOKEN --name "$RUNNER_NAME" --labels "self-hosted,Linux,X64" --work _work
sudo ./svc.sh install
EOT
    )
  }

  storage_profile_os_disk {
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = var.managed_disk_type
  }

  storage_profile_data_disk {
    lun               = 0
    caching           = "ReadWrite"
    create_option     = "Empty"
    disk_size_gb      = var.data_disk_size_gb
    managed_disk_type = var.managed_disk_type
  }

  storage_profile_image_reference {
    publisher = var.os_image_publisher
    offer     = var.os_image_offer
    sku       = var.os_image_sku
    version   = var.os_image_version
  }
}

resource "azurerm_bastion_host" "mockten_bastion" {
  name                    = "mockten-bastion"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku                     = "Developer"
  virtual_network_id      = var.mockten_vnet
}
