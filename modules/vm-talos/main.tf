terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
  }
}

locals {
  network_gateway = var.pool_gateway != null ? var.pool_gateway : var.common_gateway
  ip_cidr         = var.pool_cidr != null ? var.pool_cidr : var.common_cidr

  # Flatten control_plane + worker_nodes into a single VM map
  all_nodes = merge(
    {
      for i in range(var.control_plane.count) :
      "${var.name}-cp-${format("%02d", i + 1)}" => {
        role     = "cp"
        cpu      = var.control_plane.cpu
        memory   = var.control_plane.memory
        disk     = var.control_plane.disk
        tags     = concat([terraform.workspace, "talos"], var.control_plane.tags)
        ip_start = var.control_plane.ip_start
        index    = i
      }
    },
    {
      for i in range(var.worker_nodes.count) :
      "${var.name}-wk-${format("%02d", i + 1)}" => {
        role     = "wk"
        cpu      = var.worker_nodes.cpu
        memory   = var.worker_nodes.memory
        disk     = var.worker_nodes.disk
        tags     = concat([terraform.workspace, "talos"], var.worker_nodes.tags)
        ip_start = var.worker_nodes.ip_start
        index    = i
      }
    }
  )
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.all_nodes

  name        = each.key
  description = var.desc
  node_name   = var.proxmox_node
  machine     = "q35"

  pool_id = var.pool_id
  started = true
  tags    = each.value.tags

  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
    numa  = true
  }

  memory {
    dedicated = each.value.memory
    floating  = 0
  }

  # Blank raw disk for Talos to install onto
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
    size         = each.value.disk
    file_format  = "raw"
  }

  # Boot ISO
  cdrom {
    file_id = var.talos_iso_id
  }

  network_device {
    bridge = "vmbr0"
  }

  serial_device {
    device = "socket"
  }
}
