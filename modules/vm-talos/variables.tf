variable "proxmox_node" {
  description = "Name of the Proxmox node"
  type        = string
}

variable "name" {
  description = "Cluster name"
  type        = string
}

variable "desc" {
  description = "Cluster description"
  type        = string
}

variable "cluster_vip" {
  description = "Virtual IP for the cluster API endpoint"
  type        = string
}

variable "talos_iso_id" {
  description = "Proxmox file ID for the Talos ISO"
  type        = string
}

variable "common_gateway" {
  description = "Default gateway IP"
  type        = string
}

variable "common_cidr" {
  description = "Default network CIDR"
  type        = string
}

variable "pool_id" {
  description = "Proxmox resource pool ID"
  type        = string
}

variable "pool_gateway" {
  description = "Pool-specific gateway (overrides common)"
  type        = string
  default     = null
}

variable "pool_cidr" {
  description = "Pool-specific CIDR (overrides common)"
  type        = string
  default     = null
}

variable "control_plane" {
  description = "Control plane node configuration"
  type = object({
    count    = number
    cpu      = number
    memory   = number
    disk     = optional(number, 50)
    tags     = string
    ip_start = number
  })
}

variable "worker_nodes" {
  description = "Worker node configuration"
  type = object({
    count    = number
    cpu      = number
    memory   = number
    disk     = optional(number, 100)
    tags     = string
    ip_start = number
  })
}
