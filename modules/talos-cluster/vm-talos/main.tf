terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
    talos   = { source = "siderolabs/talos" }
  }
}

locals {
  tags = concat([terraform.workspace, "talos", "k8s"], var.control_plane.tags)

  cp_nodes = {
    for i in range(var.control_plane.count) :
    "${var.name}-ctrl-${format("%02d", i + 1)}" => {
      ip                        = cidrhost(var.pool_cidr != null ? var.pool_cidr : var.common_cidr, var.control_plane.ip_start + i)
      tags                      = ["cp"]
      role                      = "cp"
      node_labels               = var.control_plane.node_labels
      node_taints               = var.control_plane.node_taints
      ephemeral_volume_grow     = var.control_plane.ephemeral_volume_grow
      ephemeral_volume_max_size = var.control_plane.ephemeral_volume_max_size
      ephemeral_volume_min_size = var.control_plane.ephemeral_volume_min_size
    }
  }

  wk_nodes = {
    for i in range(var.worker_nodes.count) :
    "${var.name}-worker-${format("%02d", i + 1)}" => {
      ip                        = cidrhost(var.pool_cidr != null ? var.pool_cidr : var.common_cidr, var.worker_nodes.ip_start + i)
      tags                      = ["wk"]
      role                      = "wk"
      node_labels               = var.worker_nodes.node_labels
      node_taints               = var.worker_nodes.node_taints
      ephemeral_volume_grow     = var.worker_nodes.ephemeral_volume_grow
      ephemeral_volume_max_size = var.worker_nodes.ephemeral_volume_max_size
      ephemeral_volume_min_size = var.worker_nodes.ephemeral_volume_min_size
    }
  }

  all_nodes = merge(local.cp_nodes, local.wk_nodes)

  network_gateway  = var.pool_gateway != null ? var.pool_gateway : var.common_gateway
  cluster_endpoint = "https://${var.cluster_vip}:${var.cluster_endpoint_port}"

  first_cp_name = keys(local.cp_nodes)[0]
}

# Upload Talos machine configurations as snippets
resource "proxmox_virtual_environment_file" "talos_config" {
  for_each = local.all_nodes

  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data      = data.talos_machine_configuration.node[each.key].machine_configuration
    file_name = "talos-${each.key}.yaml"
  }

  # This ensures k8s_node_cleanup is created BEFORE the config file,
  # and thus destroyed AFTER the VM and the config file are gone.
  depends_on = [terraform_data.k8s_node_cleanup]
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = local.all_nodes

  name        = each.key
  node_name   = var.proxmox_node
  description = var.desc
  pool_id     = var.pool_id

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0", "ide3"]

  agent {
    enabled = true
    timeout = "20s" # Short timeout to prevent creation deadlock
  }

  cpu {
    cores = each.value.role == "cp" ? var.control_plane.cpu : var.worker_nodes.cpu
    type  = var.cpu_type
    numa  = true
  }

  memory {
    dedicated = each.value.role == "cp" ? var.control_plane.memory : var.worker_nodes.memory
    floating  = var.balloon
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
    size         = each.value.role == "cp" ? var.control_plane.disk : var.worker_nodes.disk
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
  }

  cdrom {
    file_id = var.talos_iso_id
  }

  # Talos nocloud reads machine config from NoCloud datasource
  initialization {
    datastore_id      = "local-zfs"
    user_data_file_id = proxmox_virtual_environment_file.talos_config[each.key].id
  }

  smbios {
    serial = "ds=nocloud;h=${each.key}"
  }

  serial_device {
    device = "socket"
  }

  tags = concat(local.tags, each.value.tags)

  lifecycle {
    ignore_changes = [initialization]
  }
}
