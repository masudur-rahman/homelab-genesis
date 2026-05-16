terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
    talos   = { source = "siderolabs/talos" }
  }
}

module "vm_talos" {
  source = "./vm-talos"

  proxmox_node        = var.proxmox_node
  common_gateway      = var.common_gateway
  common_cidr         = var.common_cidr
  talos_iso_id        = var.talos_iso_id
  talos_install_image = var.talos_install_image

  name        = var.name
  desc        = var.desc
  cluster_vip = var.cluster_vip

  control_plane = var.control_plane
  worker_nodes  = var.worker_nodes

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  nameservers        = var.nameservers
  extra_manifests    = var.extra_manifests

  pool_gateway = var.pool_gateway
  pool_cidr    = var.pool_cidr
  pool_id      = var.pool_id
}

module "talos_addons" {
  source = "./talos-addons"

  cluster_name    = var.name
  kubeconfig_path = module.vm_talos.kubeconfig_path
  cluster_vip     = var.cluster_vip

  cilium_version      = var.cilium_version
  proxmox_csi_version = var.proxmox_csi_version
  pm_api_endpoint     = var.pm_api_endpoint
  csi_token_id        = var.csi_token_id
  csi_token_secret    = var.csi_token_secret

  depends_on = [module.vm_talos]
}
