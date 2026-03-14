terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
  }
}

locals {
  tags = concat([terraform.workspace], var.tags)

  network_gateway = var.pool_gateway != null ? var.pool_gateway : var.common_gateway
  ip_cidr         = var.pool_cidr != null ? var.pool_cidr : var.common_cidr
}

resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  count = var.vm_count

  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/cloud-init.tftpl", {
      hostname = "${var.name}-${format("%02d", count.index + 1)}"
      username = var.vm_user
      password = var.vm_password
      ssh_keys = var.ssh_keys
    })
    file_name = "user-data-${terraform.workspace}-${var.name}-${format("%02d", count.index + 1)}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  count     = var.vm_count
  name      = "${var.name}-${format("%02d", count.index + 1)}"
  node_name = var.proxmox_node

  pool_id = var.pool_id
  started = true
  tags    = local.tags

  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]
  agent {
    enabled = true
  }

  cpu {
    cores = var.cpu
    type  = var.cpu_type
    numa  = true
  }

  memory {
    dedicated = var.memory
    floating  = var.balloon
  }

  disk {
    datastore_id = "local-zfs"
    import_from  = var.cloud_image_id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
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
        address = "${cidrhost(local.ip_cidr, var.ip_start + count.index)}/24"
        gateway = local.network_gateway
      }
    }
  }

  lifecycle {
    ignore_changes = [initialization[0].user_data_file_id]
  }
}
