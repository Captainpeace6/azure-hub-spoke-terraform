output "resource_group_name" {
  description = "Hub resource group."
  value       = azurerm_resource_group.hub.name
}

output "vnet_id" {
  description = "Hub VNet ID."
  value       = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  description = "Hub VNet name."
  value       = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Next hop for spoke route tables."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "firewall_policy_id" {
  description = "Child firewall policy that spokes add rule collection groups to."
  value       = azurerm_firewall_policy.hub.id
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}
