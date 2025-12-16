output "proxmox_virtual_environment_version" {
  value = {
    release       = data.proxmox_virtual_environment_version.pm_version.release
    repository_id = data.proxmox_virtual_environment_version.pm_version.repository_id
    version       = data.proxmox_virtual_environment_version.pm_version.version
  }
}

# output "debian_template_id" {
#   value       = proxmox_virtual_environment_vm.debian_12_template.vm_id
#   description = "The ID of the Debian 12 Cloud-Init Template"
# }

output "deployed_vms" {
  value = {
    for instance in module.debian_vms :
    instance.vm_name => instance.vm_ip_address
  }
  description = "Map of VM Names to IP Addresses"
}

output "debian_vm_ips" {
  value = {
    for k, v in module.debian_vms : k => v.vm_ip_address
  }
  description = "The IP addresses of the deployed Debian VMs"
}