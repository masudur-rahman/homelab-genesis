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
    count       = number
    cpu         = number
    memory      = number
    disk        = optional(number, 50)
    tags        = list(string)
    ip_start    = number
    prefix      = optional(string)
    node_labels = optional(map(string), {})
    node_taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    ephemeral_volume_grow     = optional(bool, false)
    ephemeral_volume_max_size = optional(string, "")
    ephemeral_volume_min_size = optional(string, "")
  })

  validation {
    condition     = var.control_plane.count >= 1
    error_message = "At least one control plane node is required."
  }
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
    count       = number
    cpu         = number
    memory      = number
    disk        = optional(number, 100)
    tags        = list(string)
    ip_start    = number
    prefix      = optional(string)
    node_labels = optional(map(string), {})
    node_taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    ephemeral_volume_grow     = optional(bool, false)
    ephemeral_volume_max_size = optional(string, "")
    ephemeral_volume_min_size = optional(string, "")
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

# --- Talos Cluster Lifecycle ---

variable "talos_version" {
  description = "Talos OS version"
  type        = string
  default     = "v1.12.2"
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy"
  type        = string
  default     = "1.32.3"
}

variable "nameservers" {
  description = "DNS nameservers for nodes"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "cluster_endpoint_port" {
  description = "Kubernetes API server port"
  type        = number
  default     = 6443
}

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.17.3"
}

variable "proxmox_csi_version" {
  description = "Proxmox CSI plugin Helm chart version"
  type        = string
  default     = "0.10.1"
}

variable "pm_api_endpoint" {
  description = "Proxmox API URL for CSI configuration"
  type        = string
}

variable "topology_region" {
  description = "Topology region label for CSI"
  type        = string
  default     = "homelab"
}

variable "topology_zone" {
  description = "Topology zone label for CSI"
  type        = string
  default     = "pve"
}
