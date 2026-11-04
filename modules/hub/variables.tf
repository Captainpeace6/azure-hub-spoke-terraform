variable "name" {
  description = "Name prefix for hub resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "Hub VNet address space."
  type        = list(string)
}

variable "firewall_subnet_prefix" {
  description = "Prefix for AzureFirewallSubnet (must be at least /26)."
  type        = string
}

variable "zones" {
  description = "Availability zones for the firewall and its public IP."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "log_retention_days" {
  description = "Log Analytics retention."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
