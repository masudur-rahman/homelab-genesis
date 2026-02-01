output "debian_12_id" {
  value = proxmox_virtual_environment_download_file.generic_iso["debian-12"].id
}
