output "data_proxmox_virtual_environment_version" {
  value = {
    release       = data.proxmox_virtual_environment_version.pm_version.release
    repository_id = data.proxmox_virtual_environment_version.pm_version.repository_id
    version       = data.proxmox_virtual_environment_version.pm_version.version
  }
}
