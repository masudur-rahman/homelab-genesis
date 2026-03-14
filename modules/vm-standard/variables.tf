variable "proxmox_node" { type = string }
variable "name" { type = string }
variable "desc" { type = string }
variable "vm_count" { type = number }
variable "tags" {
  description = "Tags for the VMs"
  type        = list(string)
}
variable "cpu" {
  description = "Number of CPU cores"
  type        = number
  validation {
    condition     = var.cpu >= 1
    error_message = "CPU cores must be >= 1."
  }
}
variable "memory" {
  description = "Memory in MB"
  type        = number
  validation {
    condition     = var.memory >= 512
    error_message = "Memory must be >= 512 MB."
  }
}
variable "disk" {
  description = "Disk size in GB"
  type        = number
  validation {
    condition     = var.disk >= 8
    error_message = "Disk size must be >= 8 GB."
  }
}
variable "ip_start" { type = number }
variable "cloud_image_id" { type = string }
variable "common_gateway" { type = string }
variable "common_cidr" { type = string }
variable "ssh_keys" { type = list(string) }
variable "pool_id" { type = string } # Required
variable "vm_user" {
  description = "Default username for VM cloud-init"
  type        = string
}

variable "vm_password" {
  description = "Default password for VM cloud-init"
  type        = string
  sensitive   = true
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
  type    = string
  default = null
}
variable "pool_cidr" {
  type    = string
  default = null
}
