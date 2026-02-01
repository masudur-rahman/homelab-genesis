terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
    talos   = { source = "siderolabs/talos" }
  }
}

resource "proxmox_virtual_environment_download_file" "generic_iso" {
  for_each = var.iso_images

  content_type = "import"
  datastore_id = "local"
  node_name    = var.proxmox_node
  url          = each.value
  overwrite    = false

  file_name = "${each.key}-generic-amd64-${terraform.workspace}.qcow2"
}
