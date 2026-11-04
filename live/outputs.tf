output "firewall_private_ip" {
  description = "Hub firewall private IP (next hop for every spoke)."
  value       = module.hub.firewall_private_ip
}

output "spoke_subnet_ids" {
  description = "Subnet IDs per spoke."
  value = {
    dev  = module.spoke_dev.subnet_ids
    prod = module.spoke_prod.subnet_ids
  }
}
