output "vm_info" {
  description = "Map of VM names to IP addresses for this cluster"
  value = {
    for name, vm in proxmox_virtual_environment_vm.talos :
    name => "${cidrhost(local.ip_cidr, local.all_nodes[name].ip_start + local.all_nodes[name].index)}/24"
  }
}

output "control_plane_ips" {
  description = "List of control plane IP addresses"
  value = [
    for name, cfg in local.all_nodes :
    cidrhost(local.ip_cidr, cfg.ip_start + cfg.index)
    if cfg.role == "cp"
  ]
}

output "worker_ips" {
  description = "List of worker node IP addresses"
  value = [
    for name, cfg in local.all_nodes :
    cidrhost(local.ip_cidr, cfg.ip_start + cfg.index)
    if cfg.role == "wk"
  ]
}
