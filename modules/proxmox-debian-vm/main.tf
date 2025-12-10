# terraform {
#   required_providers {
#     proxmox = {
#       source  = "bpg/proxmox"
#       version = "~> 0.89.1"
#     }
#   }
# }

# 1. Find the template by name (so we don't have to memorize ID 9000)
data "proxmox_virtual_environment_vms" "template_finder" {
  node_name = var.node_name
  tags      = [var.template_name]
}

resource "proxmox_virtual_environment_vm" "debian_vm" {
  name      = var.name
  node_name = var.node_name
  vm_id     = var.vm_id
  pool_id   = var.pool_id

  # Clone configuration
  template = true
  source_vm_id = data.proxmox_virtual_environment_vms.template_finder.vms[0].vm_id

  # Start the VM after creation
  started = true
  
  agent {
    enabled = true
  }

  cpu {
    cores = var.cpu_cores
    type  = "x86-64-v2-AES" # Good baseline for modern CPUs
  }

  memory {
    dedicated = var.memory_mb
    floating  = var.memory_mb # Disable ballooning for stability
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size_gb
    file_format  = "raw" # ZFS uses raw
  }

  network_device {
    bridge = "vmbr0"
  }

  # Cloud-Init Configuration
  initialization {
    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    user_account {
      username = "debian"
      keys     = var.ssh_keys
    }
  }
}
