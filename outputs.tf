output "proxmox_virtual_environment_version" {
  value = {
    release       = data.proxmox_virtual_environment_version.pm_version.release
    repository_id = data.proxmox_virtual_environment_version.pm_version.repository_id
    version       = data.proxmox_virtual_environment_version.pm_version.version
  }
}

output "debian_template_id" {
  value       = proxmox_virtual_environment_vm.debian_12_template.vm_id
  description = "The ID of the Debian 12 Cloud-Init Template"
}
