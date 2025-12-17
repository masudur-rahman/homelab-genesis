output "proxmox_virtual_environment_version" {
  value = {
    release       = data.proxmox_virtual_environment_version.pm_version.release
    repository_id = data.proxmox_virtual_environment_version.pm_version.repository_id
    version       = data.proxmox_virtual_environment_version.pm_version.version
  }
}

output "cluster_nodes" {
  description = "Deployed VMs grouped by Node Pool"
  value = {
    for pool_name, pool_module in module.node_pools :
    pool_name => pool_module.vm_info
  }
}

output "all_ips" {
  description = "Flattened list of all IP addresses"
  value = flatten([
    for pool in module.node_pools : values(pool.vm_info)
  ])
}