terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.89.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_endpoint
  api_token = var.pm_api_token
  insecure  = var.pm_insecure

  ssh {
    agent    = true
    username = "root"
  }
}

data "proxmox_virtual_environment_version" "pm_version" {}

module "node_pools" {
  source = "./modules/proxmox-debian-vm"

  for_each = var.node_pools

  node_name        = "pve"
  pool_id          = proxmox_virtual_environment_pool.development.pool_id
  cloud_image_id   = proxmox_virtual_environment_download_file.debian_12_cloud_image.id
  # template_vm_id   = proxmox_virtual_environment_vm.debian_12_template.vm_id
  ci_template_path = "${path.root}/templates/cloud-init.tftpl"
  ssh_keys         = var.ssh_public_keys

  pool_name = each.key

  # Pass the Pool Configuration Object
  vm_count = each.value.vm_count
  tags     = each.value.tags

  # Hardware
  cpu    = each.value.cpu
  memory = each.value.memory
  disk   = each.value.disk

  # Network Logic (Pool Specific)
  ip_start     = each.value.ip_start
  pool_gateway = each.value.gateway
  pool_cidr    = each.value.cidr

  # Global Defaults (For fallback inside the module)
  common_gateway = var.common_gateway
  common_cidr    = var.common_cidr
}
