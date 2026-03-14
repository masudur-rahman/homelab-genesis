output "vm_info" {
  description = "Map of VM names to IP addresses"
  value = {
    for vm in proxmox_virtual_environment_vm.vm :
    vm.name => vm.initialization[0].ip_config[0].ipv4[0].address
  }
}
