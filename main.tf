locals {
  resource_pools = sort(distinct(compact(concat(
    [for k, v in var.debian_vms : v.pool],
    [for k, v in var.flatcar_vms : v.pool],
    [for k, v in var.talos_clusters : v.pool],
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
  vm_user        = var.vm_user
  vm_password    = var.vm_password
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

module "vm_talos" {
  source   = "./modules/vm-talos"
  for_each = var.talos_clusters

  proxmox_node   = var.proxmox_node
  common_gateway = var.common_gateway
  common_cidr    = var.common_cidr
  talos_iso_id   = module.bootstrap.talos_iso_ids[each.value.talos_version]

  name        = each.key
  desc        = each.value.desc
  cluster_vip = each.value.cluster_vip

  control_plane = each.value.control_plane
  worker_nodes  = each.value.worker_nodes

  talos_version      = each.value.talos_version
  kubernetes_version = each.value.kubernetes_version
  pm_api_endpoint    = var.pm_api_endpoint

  pool_gateway = each.value.gateway
  pool_cidr    = each.value.cidr
  pool_id      = module.structure.pool_ids[coalesce(each.value.pool, var.common_pool)]
}

module "vm_flatcar" {
  source   = "./modules/vm-flatcar"
  for_each = var.flatcar_vms

  proxmox_node   = var.proxmox_node
  common_gateway = var.common_gateway
  common_cidr    = var.common_cidr
  ssh_keys       = var.ssh_public_keys

  # Image Source
  cloud_image_id = module.bootstrap.generic_iso_ids["flatcar-stable"]

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
  pool_id      = module.structure.pool_ids[coalesce(each.value.pool, var.common_pool)]
}
