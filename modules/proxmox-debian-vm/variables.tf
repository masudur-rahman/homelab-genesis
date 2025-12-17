variable "pool_name" {
  description = "Name of the Node Pool (used for hostname generation)"
  type        = string
}

variable "vm_count" {
  description = "Number of VMs to create in this pool"
  type        = number
}

variable "ip_start" {
  description = "Starting Host ID for IPs (e.g. 50 -> .50, .51, .52)"
  type        = number
}

# --- Hardware ---
variable "cpu" { type = number }
variable "memory" { type = number }
variable "disk" { type = number }
variable "tags" { type = string }

# --- Network Logic ---
variable "pool_gateway" {
  description = "Pool-specific gateway override (optional)"
  type        = string
  default     = null
}

variable "pool_cidr" {
  description = "Pool-specific CIDR override (optional)"
  type        = string
  default     = null
}

variable "common_gateway" { type = string }
variable "common_cidr" { type = string }

# --- Standard ---
variable "node_name" { type = string }
variable "pool_id" { type = string }
variable "template_vm_id" { type = number }
# variable "disk_file_id" { type = string }
variable "ssh_keys" { type = list(string) }