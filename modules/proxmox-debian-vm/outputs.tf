output "vm_ip_address" {
  value = proxmox_virtual_environment_vm.debian_vm.ipv4_addresses[1][0]
  description = "The IP address of the deployed VM"
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.debian_vm.vm_id
}
