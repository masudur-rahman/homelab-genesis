output "proxmox_virtual_environment_version" {
  value = {
    release       = data.proxmox_virtual_environment_version.pm_version.release
    repository_id = data.proxmox_virtual_environment_version.pm_version.repository_id
    version       = data.proxmox_virtual_environment_version.pm_version.version
  }
}

output "resource_pools" {
  value = [
    for pool in module.structure.pool_ids : pool
  ]
}

output "nodes" {
  description = "Information of Provisioned Nodes"
  value       = { for pool_name, pool_module in module.vm_standard : pool_name => pool_module.vm_info }
}

output "all_ips" {
  description = "Flattened list of all IP addresses"
  value = flatten([
    for pool in module.vm_standard : values(pool.vm_info)
  ])
}
