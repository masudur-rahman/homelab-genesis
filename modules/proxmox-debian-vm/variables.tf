variable "node_name" {
  description = "Name of the Proxmox node (e.g., pve)"
  type        = string
}

variable "vm_id" {
  description = "The ID of the VM in Proxmox (e.g., 801)"
  type        = number
}

variable "name" {
  description = "The hostname of the VM"
  type        = string
}

variable "pool_id" {
  description = "The Resource Pool ID (e.g., development)"
  type        = string
}

variable "template_name" {
  description = "The name of the VM template to clone (e.g., debian-12-cloudinit)"
  type        = string
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "disk_size_gb" {
  description = "Root disk size in GB"
  type        = number
  default     = 10
}

variable "ipv4_address" {
  description = "CIDR format IP address (e.g., 192.168.0.50/24)"
  type        = string
}

variable "ipv4_gateway" {
  description = "Gateway IP address (e.g., 192.168.0.1)"
  type        = string
}

variable "ssh_keys" {
  description = "List of Public SSH Keys to inject"
  type        = list(string)
  default     = []
}
