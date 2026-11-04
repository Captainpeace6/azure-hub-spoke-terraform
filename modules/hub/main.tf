resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.address_space
  tags                = var.tags
}

# Azure requires this exact subnet name for the firewall.
resource "azurerm_subnet" "firewall" {
  #checkov:skip=CKV2_AZURE_31:Azure does not allow an NSG on AzureFirewallSubnet
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

resource "azurerm_public_ip" "firewall" {
  name                = "pip-afw-${var.name}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

# --- Firewall policy hierarchy ---------------------------------------------
# Parent ("baseline") holds org-wide guardrails. The child policy attached to the
# firewall inherits them and adds one rule collection group per spoke, so a team
# can change its own spoke's rules without touching the baseline.

resource "azurerm_firewall_policy" "baseline" {
  #checkov:skip=CKV_AZURE_220:IDPS needs the Premium SKU; Standard is the cost trade-off here (see README)
  name                     = "afwp-${var.name}-baseline"
  location                 = azurerm_resource_group.hub.location
  resource_group_name      = azurerm_resource_group.hub.name
  sku                      = "Standard"
  threat_intelligence_mode = "Deny"

  dns {
    proxy_enabled = true
  }

  tags = var.tags
}

resource "azurerm_firewall_policy" "hub" {
  #checkov:skip=CKV_AZURE_220:IDPS needs the Premium SKU; Standard is the cost trade-off here (see README)
  name                     = "afwp-${var.name}"
  location                 = azurerm_resource_group.hub.location
  resource_group_name      = azurerm_resource_group.hub.name
  sku                      = "Standard"
  base_policy_id           = azurerm_firewall_policy.baseline.id
  threat_intelligence_mode = "Deny"

  dns {
    proxy_enabled = true
  }

  tags = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "baseline" {
  name               = "baseline"
  firewall_policy_id = azurerm_firewall_policy.baseline.id
  priority           = 100

  application_rule_collection {
    name     = "allow-platform-endpoints"
    priority = 100
    action   = "Allow"

    rule {
      name             = "azure-and-os-updates"
      source_addresses = ["10.0.0.0/8"]
      destination_fqdns = [
        "*.ubuntu.com",
        "packages.microsoft.com",
        "*.monitor.azure.com",
        "*.blob.core.windows.net",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_firewall" "this" {
  #checkov:skip=CKV_AZURE_216:Threat intel is set to Deny on the attached firewall policy; the firewall-level setting conflicts with a policy
  name                = "afw-${var.name}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  zones               = var.zones

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = var.tags

  depends_on = [azurerm_firewall_policy_rule_collection_group.baseline]
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "to-log-analytics"
  target_resource_id             = azurerm_firewall.this.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }
}
