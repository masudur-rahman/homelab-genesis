terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
    talos   = { source = "siderolabs/talos" }
    tls     = { source = "hashicorp/tls" }
    helm    = { source = "hashicorp/helm" }
  }
}

locals {
  network_gateway = var.pool_gateway != null ? var.pool_gateway : var.common_gateway
  ip_cidr         = var.pool_cidr != null ? var.pool_cidr : var.common_cidr

  cp_prefix = coalesce(var.control_plane.prefix, "${var.name}-cp")
  wk_prefix = coalesce(var.worker_nodes.prefix, "${var.name}-wk")

  # Flatten control_plane + worker_nodes into a single VM map
  all_nodes = merge(
    {
      for i in range(var.control_plane.count) :
      "${local.cp_prefix}-${format("%02d", i + 1)}" => {
        role                      = "cp"
        cpu                       = var.control_plane.cpu
        memory                    = var.control_plane.memory
        disk                      = var.control_plane.disk
        tags                      = concat([terraform.workspace, "talos"], var.control_plane.tags)
        ip_start                  = var.control_plane.ip_start
        index                     = i
        ip                        = cidrhost(local.ip_cidr, var.control_plane.ip_start + i)
        node_labels               = var.control_plane.node_labels
        node_taints               = var.control_plane.node_taints
        ephemeral_volume_grow     = var.control_plane.ephemeral_volume_grow
        ephemeral_volume_max_size = var.control_plane.ephemeral_volume_max_size
        ephemeral_volume_min_size = var.control_plane.ephemeral_volume_min_size
      }
    },
    {
      for i in range(var.worker_nodes.count) :
      "${local.wk_prefix}-${format("%02d", i + 1)}" => {
        role                      = "wk"
        cpu                       = var.worker_nodes.cpu
        memory                    = var.worker_nodes.memory
        disk                      = var.worker_nodes.disk
        tags                      = concat([terraform.workspace, "talos"], var.worker_nodes.tags)
        ip_start                  = var.worker_nodes.ip_start
        index                     = i
        ip                        = cidrhost(local.ip_cidr, var.worker_nodes.ip_start + i)
        node_labels               = var.worker_nodes.node_labels
        node_taints               = var.worker_nodes.node_taints
        ephemeral_volume_grow     = var.worker_nodes.ephemeral_volume_grow
        ephemeral_volume_max_size = var.worker_nodes.ephemeral_volume_max_size
        ephemeral_volume_min_size = var.worker_nodes.ephemeral_volume_min_size
      }
    }
  )

  cluster_endpoint = "https://${var.cluster_vip}:${var.cluster_endpoint_port}"
  first_cp_name    = "${local.cp_prefix}-01"
  cp_nodes         = { for k, v in local.all_nodes : k => v if v.role == "cp" }
  wk_nodes         = { for k, v in local.all_nodes : k => v if v.role == "wk" }
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
    type  = var.cpu_type
    numa  = true
  }

  memory {
    dedicated = each.value.memory
    floating  = var.balloon
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
