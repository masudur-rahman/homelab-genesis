
output "vm_name" {
  value       = proxmox_virtual_environment_vm.debian_vm.name
  description = "The name of the VM"
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.debian_vm.vm_id
}

output "vm_ip_address" {
  value       = try(proxmox_virtual_environment_vm.debian_vm.ipv4_addresses[1][0], "waiting-for-agent")
  description = "The IP address of the deployed VM"
}
