variable "pm_api_endpoint" {
  type        = string
  description = "The base URL for the Proxmox API (e.g., https://192.168.0.10:8006/)"
}

variable "pm_api_token" {
  type        = string
  sensitive   = true
  description = "The Proxmox API token (format: USER@REALM!TOKENID=UUID)"
}

variable "pm_insecure" {
  type        = bool
  default     = true
  description = "Whether to ignore SSL certificate errors (true for self-signed certs)"
}
# --- Global Defaults ---
variable "proxmox_node" {
  description = "Name of the Proxmox Node"
  type        = string
  default     = "pve"
}

variable "common_gateway" {
  description = "Default Gateway IP (fallback if not defined in pool)"
  type        = string
}

variable "common_cidr" {
  description = "Default Network CIDR (fallback if not defined in pool)"
  type        = string
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for VMs"
  type        = list(string)
}


variable "common_pool" {
  description = "Default pool for VMs if not specified"
  type        = string
  default     = ""
}

variable "iso_images" {
  description = "Map of generic Cloud/ISO images to download"
  type        = map(string)
  default = {
    "debian-12" = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  }
}

variable "talos_images" {
  description = "Map of Talos configurations to build and download"
  type = map(object({
    version    = string
    extensions = list(string)
  }))
  default = {}
}

variable "vm_user" {
  description = "Default username for VM cloud-init"
  type        = string
}

variable "vm_password" {
  description = "Default password for VM cloud-init"
  type        = string
  sensitive   = true
}

# --- Standard VMs (Debian/Ubuntu) ---
variable "debian_vms" {
  description = "Standard VMs using Cloud-Init"
  type = map(object({
    desc     = string
    pool     = optional(string)
    vm_count = number
    tags     = string
    cpu      = number
    memory   = number
    disk     = number
    ip_start = number
    gateway  = optional(string)
    cidr     = optional(string)
  }))
  default = {}
}

variable "node_pools" {
  description = "Map of Node Pools"
  type = map(object({
    desc     = string
    vm_count = number
    tags     = string

    cpu    = number
    memory = number
    disk   = number

    ip_start = number # e.g. 50 starts at .50

    gateway = optional(string)
    cidr    = optional(string)
  }))
  default = {}
}

# --- Flatcar VMs (Placeholder) ---
variable "flatcar_vms" {
  type    = map(any)
  default = {}
}

# --- Talos Clusters ---
variable "talos_clusters" {
  description = "Talos K8s clusters to provision"
  type = map(object({
    desc          = string
    talos_version = optional(string, "v1.12.2")
    cluster_vip   = string
    pool          = optional(string)
    gateway       = optional(string)
    cidr          = optional(string)
    control_plane = object({
      count    = number
      cpu      = number
      memory   = number
      disk     = optional(number, 50)
      tags     = string
      ip_start = number
    })
    worker_nodes = object({
      count    = number
      cpu      = number
      memory   = number
      disk     = optional(number, 100)
      tags     = string
      ip_start = number
    })
  }))
  default = {}
}
