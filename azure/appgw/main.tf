# Application Gateway (WAF_v2) — the Azure cloud-native ingress data plane, the
# counterpart to the AWS ALB. AGIC (enabled on the AKS cluster in ../aks) programs
# its listeners/pools/rules from the Kubernetes Ingresses, so everything AGIC
# manages is under lifecycle.ignore_changes here; Terraform only owns the shell
# (SKU, subnet, frontend IP/port) and the WAF policy.
#
# This is "brownfield" AGIC on purpose: Terraform owns the gateway so Front Door
# can point at it and the WAF policy is ours. The gateway must therefore exist
# BEFORE the cluster's AGIC add-on references it — hence this module runs before
# ../aks.
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

resource "azurerm_public_ip" "appgw" {
  name                = "${var.name_prefix}-appgw-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  # A DNS label gives the gateway a stable FQDN for Front Door to use as origin.
  domain_name_label = "${var.name_prefix}-appgw-${substr(md5(var.resource_group_name), 0, 8)}"
}

# WAF policy: per-user IP restriction. Clients reach the gateway directly (there is
# no Front Door on Free Trial), so the connection IP is the real client IP and
# IPMatch on RemoteAddr works natively — CIDR ranges included. Block anything not in
# the allowlist. The subnet NSG (../nw) also gates this at L3.
resource "azurerm_web_application_firewall_policy" "appgw" {
  name                = "${var.name_prefix}-appgw-waf"
  location            = var.location
  resource_group_name = var.resource_group_name

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  custom_rules {
    name      = "AllowOnlyAllowlistClientIP"
    priority  = 1
    rule_type = "MatchRule"
    action    = "Block"
    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator           = "IPMatch"
      negation_condition = true
      # Real allowlisted clients + the cluster's own egress IP (so the dashboard's
      # in-cluster health check of the public HTTPS endpoint is not blocked).
      match_values = concat([for c in split(",", var.allowlist_cidr) : trimspace(c)], ["${var.aks_egress_ip}/32"])
    }
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_application_gateway" "this" {
  name                = "${var.name_prefix}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  firewall_policy_id  = azurerm_web_application_firewall_policy.appgw.id

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "gwip"
    subnet_id = var.appgw_subnet_id
  }

  frontend_ip_configuration {
    name                 = "feip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  # Placeholder pool/settings/listener/rule. AGIC replaces all of these from the
  # Ingresses; they exist only so the gateway is valid at create time.
  backend_address_pool {
    name = "placeholder"
  }
  backend_http_settings {
    name                  = "placeholder"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }
  http_listener {
    name                           = "placeholder"
    frontend_ip_configuration_name = "feip"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }
  request_routing_rule {
    name                       = "placeholder"
    rule_type                  = "Basic"
    priority                   = 1
    http_listener_name         = "placeholder"
    backend_address_pool_name  = "placeholder"
    backend_http_settings_name = "placeholder"
  }

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      probe,
      url_path_map,
      redirect_configuration,
      rewrite_rule_set,
      ssl_certificate,
      frontend_port,
      tags,
    ]
  }
}
