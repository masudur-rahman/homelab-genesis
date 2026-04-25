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

# --- 2. Talos Image Factory Pipeline ---
data "talos_image_factory_extensions_versions" "this" {
  for_each = var.talos_images

  talos_version = each.value.version
  filters = {
    names = each.value.extensions
  }
}

# B. Generate Schematic (The "Recipe")
resource "talos_image_factory_schematic" "this" {
  for_each = var.talos_images

  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this[each.key].extensions_info.*.name
      }
    }
  })
}

data "talos_image_factory_urls" "this" {
  for_each = var.talos_images

  talos_version = each.value.version
  schematic_id  = talos_image_factory_schematic.this[each.key].id
  platform      = "nocloud"
}

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  for_each = var.talos_images

  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node

  overwrite = false

  file_name = "talos-${each.value.version}-${talos_image_factory_schematic.this[each.key].id}-${terraform.workspace}.iso"

  url = data.talos_image_factory_urls.this[each.key].urls.iso
}
