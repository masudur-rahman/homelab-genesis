output "cilium_installed" {
  description = "Cilium installation status"
  value       = terraform_data.cilium_install.id != "" ? true : false
}

output "csi_installed" {
  description = "Proxmox CSI installation status"
  value       = terraform_data.csi_install.id != "" ? true : false
}
