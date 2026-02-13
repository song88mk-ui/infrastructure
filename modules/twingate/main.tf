provider "twingate" {
  api_token = var.api_token
  network   = var.network
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    twingate = {
      source  = "Twingate/twingate"
      version = "~> 3.7"
    }
  }
}

locals {
  processed_networks = {
    for k, v in var.remote_networks : k => {
      name             = v.name
      location         = lookup(v, "location", "OTHER")
      total_connectors = lookup(v, "total_connectors", 0)
    }
  }

  connectors_map = merge([
    for network_key, network in local.processed_networks : {
      for i in range(network.total_connectors) :
      "${network_key}-${i}" => {
        network_key = network_key
        name        = "twingate-${network_key}-connector-${i}"
      }
    }
  ]...)
}

resource "twingate_remote_network" "networks" {
  for_each = var.remote_networks

  name     = each.value.name
  location = try(each.value.location, "OTHER")
}

resource "twingate_connector" "connectors" {
  for_each = local.connectors_map

  remote_network_id = twingate_remote_network.networks[each.value.network_key].id
  name              = each.value.name
}

resource "twingate_group" "groups" {
  for_each = var.groups

  name               = each.value.name
  security_policy_id = each.value.security_policy_id
  user_ids           = each.value.user_ids
}

resource "twingate_resource" "resources" {
  for_each = var.resources

  name               = each.value.name
  address            = each.value.address
  remote_network_id  = twingate_remote_network.networks[each.value.remote_network_key].id

  alias              = try(each.value.alias, null)
  is_active          = try(each.value.is_active, true)
  is_visible         = try(each.value.is_visible, true)
  security_policy_id = try(each.value.security_policy_id, null)

  is_browser_shortcut_enabled = try(each.value.is_browser_shortcut_enabled, false)

  dynamic "access_group" {
    for_each = each.value.access_groups
    content {
      group_id = twingate_group.groups[access_group.value].id
    }
  }
}
