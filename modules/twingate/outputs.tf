output "remote_network_ids" {
  description = "Map of remote network keys to their IDs"
  value = {
    for k, v in twingate_remote_network.networks : k => v.id
  }
}

output "group_ids" {
  description = "Map of group keys to their IDs"
  value = {
    for k, v in twingate_group.groups : k => v.id
  }
}

output "resource_ids" {
  description = "Map of resource keys to their IDs"
  value = {
    for k, v in twingate_resource.resources : k => v.id
  }
}
