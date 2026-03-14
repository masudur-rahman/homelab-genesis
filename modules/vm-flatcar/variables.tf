variable "proxmox_node" {
  description = "Name of the Proxmox node"
  type        = string
}

variable "name" {
  description = "VM group name"
  type        = string
}

variable "desc" {
  description = "VM description"
  type        = string
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
}

variable "tags" {
  description = "Tags for the VMs"
  type        = list(string)
}

variable "cpu" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "disk" {
  description = "Disk size in GB"
  type        = number
}

variable "ip_start" {
  description = "Starting IP offset within the CIDR"
  type        = number
}

variable "cloud_image_id" {
  description = "Proxmox file ID for the Flatcar QCOW2 image"
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

variable "ssh_keys" {
  description = "List of SSH public keys"
  type        = list(string)
}

variable "pool_id" {
  description = "Proxmox resource pool ID"
  type        = string
}

variable "cpu_type" {
  description = "CPU type for VMs"
  type        = string
  default     = "x86-64-v2-AES"
}

variable "balloon" {
  description = "Minimum memory for balloon (null = provider default)"
  type        = number
  default     = null
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
