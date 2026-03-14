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

variable "cpu_type" {
  description = "CPU type for VMs (Talos requires host)"
  type        = string
  default     = "host"
}

variable "balloon" {
  description = "Minimum memory for balloon (Talos requires 0 to disable)"
  type        = number
  default     = 0
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
    tags     = list(string)
    ip_start = number
  })

  validation {
    condition     = var.control_plane.cpu >= 1
    error_message = "Control plane CPU cores must be >= 1."
  }
  validation {
    condition     = var.control_plane.memory >= 512
    error_message = "Control plane memory must be >= 512 MB."
  }
  validation {
    condition     = var.control_plane.disk >= 8
    error_message = "Control plane disk must be >= 8 GB."
  }
}

variable "worker_nodes" {
  description = "Worker node configuration"
  type = object({
    count    = number
    cpu      = number
    memory   = number
    disk     = optional(number, 100)
    tags     = list(string)
    ip_start = number
  })

  validation {
    condition     = var.worker_nodes.cpu >= 1
    error_message = "Worker node CPU cores must be >= 1."
  }
  validation {
    condition     = var.worker_nodes.memory >= 512
    error_message = "Worker node memory must be >= 512 MB."
  }
  validation {
    condition     = var.worker_nodes.disk >= 8
    error_message = "Worker node disk must be >= 8 GB."
  }
}
