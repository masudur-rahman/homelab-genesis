output "debian_12_id" {
  value = proxmox_virtual_environment_download_file.generic_iso["debian-12"].id
}

output "generic_iso_map" {
  description = "map of generic iso resources"
  value       = proxmox_virtual_environment_download_file.generic_iso
}

output "talos_iso_map" {
  description = "Map of Talos ISO resources"
  value       = proxmox_virtual_environment_download_file.talos_iso
}

# 2. Output simplified ID maps (Easier to read in consuming modules)
output "generic_iso_ids" {
  value = {
    for k, v in proxmox_virtual_environment_download_file.generic_iso : k => v.id
  }
}

output "talos_iso_ids" {
  value = {
    for k, v in proxmox_virtual_environment_download_file.talos_iso : k => v.id
  }
}

output "talos_installer_images" {
  description = "Talos Image Factory installer image references per version"
  value = {
    for k, v in data.talos_image_factory_urls.this : v.talos_version => v.urls.installer
  }
}
