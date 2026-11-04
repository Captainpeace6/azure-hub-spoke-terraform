resource "azurerm_resource_group" "spoke" {
  name     = "rg-spoke-${var.name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-spoke-${var.name}"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  #checkov:skip=CKV2_AZURE_31:Every subnet gets an NSG through azurerm_subnet_network_security_group_association below (for_each is not resolved by the scanner)
  for_each = var.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [each.value.prefix]
}

# --- NSGs: explicit allows, then deny everything else inbound ---------------

resource "azurerm_network_security_group" "this" {
  for_each = var.subnets

  name                = "nsg-${var.name}-${each.key}"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = each.value.inbound_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = security_rule.value.protocol
      source_address_prefixes    = security_rule.value.source_address_prefixes
      source_port_range          = "*"
      destination_address_prefix = each.value.prefix
      destination_port_ranges    = security_rule.value.destination_port_ranges
    }
  }

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# --- Force all egress through the hub firewall -----------------------------

resource "azurerm_route_table" "spoke" {
  name                          = "rt-spoke-${var.name}"
  location                      = azurerm_resource_group.spoke.location
  resource_group_name           = azurerm_resource_group.spoke.name
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = var.subnets

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.spoke.id
}

# --- Peering (both directions) ---------------------------------------------
# Peering is not transitive: dev and prod each peer only with the hub, so they
# cannot reach each other unless a firewall rule explicitly allows it.

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.name}-to-hub"
  resource_group_name       = azurerm_resource_group.spoke.name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = var.hub_vnet_id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-${var.name}"
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = true
}

# --- This spoke's firewall rules -------------------------------------------

resource "azurerm_firewall_policy_rule_collection_group" "spoke" {
  name               = "spoke-${var.name}"
  firewall_policy_id = var.firewall_policy_id
  priority           = var.firewall_rule_priority

  dynamic "application_rule_collection" {
    for_each = length(var.allowed_egress_fqdns) > 0 ? [1] : []
    content {
      name     = "allow-${var.name}-egress"
      priority = 100
      action   = "Allow"

      rule {
        name              = "https-allowlist"
        source_addresses  = var.address_space
        destination_fqdns = var.allowed_egress_fqdns
        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }
}
