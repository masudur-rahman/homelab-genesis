locals {
  resource_pools = sort(distinct(compact(concat(
    [for k, v in var.debian_vms : v.pool],
    # [for k, v in var.flatcar_vms : v.pool],
    # [for k, v in var.talos_clusters : v.pool],
    [var.common_pool]
  ))))
}

module "structure" {
  source = "./modules/structure"
  pools  = local.resource_pools
}

module "bootstrap" {
  source       = "./modules/bootstrap"
  proxmox_node = var.proxmox_node
  iso_images   = var.iso_images
  talos_images = var.talos_images
}

module "vm_standard" {
  source   = "./modules/vm-standard"
  for_each = var.debian_vms

  # Global Inputs
  proxmox_node   = var.proxmox_node
  common_gateway = var.common_gateway
  common_cidr    = var.common_cidr
  ssh_keys       = var.ssh_public_keys

  # Image Source
  cloud_image_id = module.bootstrap.debian_12_id

  # Per-VM Configuration
  name     = each.key
  desc     = each.value.desc
  vm_count = each.value.vm_count
  tags     = each.value.tags
  cpu      = each.value.cpu
  memory   = each.value.memory
  disk     = each.value.disk
  ip_start = each.value.ip_start

  pool_gateway = each.value.gateway
  pool_cidr    = each.value.cidr

  pool_id = module.structure.pool_ids[coalesce(each.value.pool, var.common_pool)]
}

# Future: module "vm_flatcar" { ... }
# Future: module "vm_talos" { ... }
