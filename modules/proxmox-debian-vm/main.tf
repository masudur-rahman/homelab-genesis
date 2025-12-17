terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.89.1"
    }
  }
}

# Calculate Network Logic Once (Local Variables)
locals {
  # Use Pool Override if present, otherwise Global Default
  final_gateway = var.pool_gateway != null ? var.pool_gateway : var.common_gateway
  final_cidr    = var.pool_cidr != null ? var.pool_cidr : var.common_cidr
}

# Generate Cloud-Init File (One per VM instance)
resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  count = var.vm_count

  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    data = templatefile(var.ci_template_path, {
      hostname = "${var.pool_name}-${format("%02d", count.index + 1)}"
      username = "unknown"
      password = "ojana"
      ssh_keys = var.ssh_keys
    })

    file_name = "user-data-${var.pool_name}-${format("%02d", count.index + 1)}.yaml"
  }
}

# Create the VMs
resource "proxmox_virtual_environment_vm" "debian_vm" {
  count = var.vm_count

  name      = "${var.pool_name}-${format("%02d", count.index + 1)}"
  node_name = var.node_name
  pool_id   = var.pool_id
  started   = true
  tags      = split(",", var.tags) # Convert string "dev,test" to list

  clone {
    vm_id = var.template_vm_id
  }

  agent {
    enabled = true
  }

  scsi_hardware = "virtio-scsi-single"

  cpu {
    cores = var.cpu
    type  = "x86-64-v2-AES"
    numa  = true
  }

  memory {
    dedicated = var.memory
    floating  = var.memory
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = var.disk
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
  }

  serial_device {
    device = "socket"
  }

  initialization {
    datastore_id      = "local-zfs"
    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config[count.index].id

    ip_config {
      ipv4 {
        address = "${cidrhost(local.final_cidr, var.ip_start + count.index)}/24"
        gateway = local.final_gateway
      }
    }
  }
}
