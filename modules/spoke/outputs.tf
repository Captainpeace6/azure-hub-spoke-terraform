output "vnet_id" {
  description = "Spoke VNet ID."
  value       = azurerm_virtual_network.spoke.id
}

output "subnet_ids" {
  description = "Subnet IDs keyed by name."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}
