resource "proxmox_virtual_environment_download_file" "debian_12_cloud_image" {
  content_type = "import"

  datastore_id = "local"
  node_name    = "pve"
  url          = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  file_name    = "debian-12-generic-amd64.qcow2"
}

# Define the "Template
resource "proxmox_virtual_environment_vm" "debian_12_template" {
  name      = "debian-12-cloudinit"
  node_name = "pve"
  template  = true
  started   = false

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = 5
    file_id      = proxmox_virtual_environment_download_file.debian_12_cloud_image.id
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    datastore_id = "local-zfs"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
