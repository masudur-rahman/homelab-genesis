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

module "debian_vms" {
  source = "./modules/proxmox-debian-vm"

  for_each = var.debian_vms

  node_name = "pve"
  pool_id   = proxmox_virtual_environment_pool.development.pool_id

  template_vm_id = proxmox_virtual_environment_vm.debian_12_template.vm_id
  disk_file_id   = proxmox_virtual_environment_download_file.debian_12_cloud_image.id

  name         = each.key
  cpu_cores    = each.value.cpu_cores
  memory_mb    = each.value.memory_mb
  disk_size_gb = each.value.disk_size_gb
  ipv4_address = each.value.ipv4_address
  ipv4_gateway = each.value.ipv4_gateway

  ssh_keys      = var.ssh_public_keys
  template_name = ""
}
