variable "name" {
  description = "Spoke name, e.g. dev or prod."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "Spoke VNet address space. Must not overlap the hub or other spokes."
  type        = list(string)
}

variable "subnets" {
  description = "Subnets in the spoke, keyed by name."
  type = map(object({
    prefix = string
    # Inbound rules on top of the default deny. Ports and sources are explicit on purpose.
    inbound_rules = optional(list(object({
      name                    = string
      priority                = number
      source_address_prefixes = list(string)
      destination_port_ranges = list(string)
      protocol                = optional(string, "Tcp")
    })), [])
  }))
}

variable "hub_vnet_id" {
  description = "Hub VNet to peer with."
  type        = string
}

variable "hub_vnet_name" {
  description = "Hub VNet name (for the hub-side peering)."
  type        = string
}

variable "hub_resource_group_name" {
  description = "Hub resource group (for the hub-side peering)."
  type        = string
}

variable "firewall_private_ip" {
  description = "Hub firewall private IP; all spoke egress is routed through it."
  type        = string
}

variable "firewall_policy_id" {
  description = "Hub child firewall policy to add this spoke's rules to."
  type        = string
}

variable "firewall_rule_priority" {
  description = "Priority of this spoke's rule collection group (unique per spoke)."
  type        = number
}

variable "allowed_egress_fqdns" {
  description = "Extra FQDNs this spoke may reach over HTTPS."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
