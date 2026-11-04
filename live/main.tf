locals {
  tags = {
    project   = "azure-hub-spoke-terraform"
    managedBy = "terraform"
  }

  # Corporate / VPN range allowed to reach app subnets.
  corp_ranges = ["172.16.0.0/12"]
}

module "hub" {
  source = "../modules/hub"

  name                   = "hub-eus2"
  location               = var.location
  address_space          = ["10.0.0.0/22"]
  firewall_subnet_prefix = "10.0.0.0/26"
  tags                   = merge(local.tags, { environment = "shared" })
}

module "spoke_dev" {
  source = "../modules/spoke"

  name          = "dev"
  location      = var.location
  address_space = ["10.1.0.0/16"]

  subnets = {
    app = {
      prefix = "10.1.1.0/24"
      inbound_rules = [{
        name                    = "allow-https-from-corp"
        priority                = 100
        source_address_prefixes = local.corp_ranges
        destination_port_ranges = ["443"]
      }]
    }
    data = {
      prefix = "10.1.2.0/24"
      inbound_rules = [{
        name                    = "allow-postgres-from-app"
        priority                = 100
        source_address_prefixes = ["10.1.1.0/24"]
        destination_port_ranges = ["5432"]
      }]
    }
  }

  hub_vnet_id             = module.hub.vnet_id
  hub_vnet_name           = module.hub.vnet_name
  hub_resource_group_name = module.hub.resource_group_name
  firewall_private_ip     = module.hub.firewall_private_ip
  firewall_policy_id      = module.hub.firewall_policy_id
  firewall_rule_priority  = 200

  # Dev may pull public packages; prod may not.
  allowed_egress_fqdns = ["registry.npmjs.org", "pypi.org", "files.pythonhosted.org", "ghcr.io"]

  tags = merge(local.tags, { environment = "dev" })
}

module "spoke_prod" {
  source = "../modules/spoke"

  name          = "prod"
  location      = var.location
  address_space = ["10.2.0.0/16"]

  subnets = {
    app = {
      prefix = "10.2.1.0/24"
      inbound_rules = [{
        name                    = "allow-https-from-corp"
        priority                = 100
        source_address_prefixes = local.corp_ranges
        destination_port_ranges = ["443"]
      }]
    }
    data = {
      prefix = "10.2.2.0/24"
      inbound_rules = [{
        name                    = "allow-postgres-from-app"
        priority                = 100
        source_address_prefixes = ["10.2.1.0/24"]
        destination_port_ranges = ["5432"]
      }]
    }
  }

  hub_vnet_id             = module.hub.vnet_id
  hub_vnet_name           = module.hub.vnet_name
  hub_resource_group_name = module.hub.resource_group_name
  firewall_private_ip     = module.hub.firewall_private_ip
  firewall_policy_id      = module.hub.firewall_policy_id
  firewall_rule_priority  = 300

  allowed_egress_fqdns = ["ghcr.io"]

  tags = merge(local.tags, { environment = "prod" })
}
