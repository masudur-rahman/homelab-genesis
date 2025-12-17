output "vm_info" {
  description = "Map of VM Names to IP Addresses for this pool"
  value = {
    for vm in proxmox_virtual_environment_vm.debian_vm :
    vm.name => vm.initialization[0].ip_config[0].ipv4[0].address
  }
}

output "vm_ids" {
  description = "List of VM IDs created in this pool"
  value       = proxmox_virtual_environment_vm.debian_vm[*].vm_id
}
