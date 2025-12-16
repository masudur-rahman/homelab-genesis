terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.89.1"
    }
  }
}

resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    data = <<EOF
#cloud-config
hostname: ${var.name}
manage_etc_hosts: true
timezone: Asia/Dhaka
users:
  - default
  - name: debian
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    passwd: debian
    ssh_authorized_keys:
%{for key in var.ssh_keys~}
      - ${key}
%{endfor~}

package_update: true
packages:
  - qemu-guest-agent
  - net-tools
  - curl

runcmd:
  - systemctl unmask qemu-guest-agent
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - echo "Cloud-Init Complete"
  - echo "Agent Started" > /tmp/agent-status.txt
EOF

    file_name = "user-data-${var.name}-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "debian_vm" {
  name      = var.name
  node_name = var.node_name
  pool_id   = var.pool_id
  started   = true

  # 👇 CLONE THE TEMPLATE (This gives us a working Disk)
  clone {
    vm_id = var.template_vm_id
  }

  agent {
    enabled = true
  }

  scsi_hardware = "virtio-scsi-single"

  cpu {
    cores = var.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory_mb
    floating  = var.memory_mb
  }

  network_device {
    bridge = "vmbr0"
  }

  serial_device {
    device = "socket"
  }

  initialization {
    datastore_id = "local-zfs"
    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }
  }
}
