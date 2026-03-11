variable "proxmox_node" {
  type    = string
  default = "pve"
}

# 1. Generic ISOs (Debian, Ubuntu, etc.)
variable "iso_images" {
  description = "Map of generic Cloud/ISO images to download"
  type        = map(string)
  default = {
    "debian-12" = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  }
}

# 2. Talos Factory Configurations
variable "talos_images" {
  description = "Map of Talos configurations to build and download"
  type = map(object({
    version    = string
    extensions = list(string)
  }))

  # Default example (Adjust as needed)
  default = {
    "v1.12.2" = {
      version    = "v1.12.2"
      extensions = ["iscsi-tools", "util-linux-tools", "qemu-guest-agent"]
    }
  }
}
