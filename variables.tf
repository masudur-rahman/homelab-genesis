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

variable "debian_vms" {
  description = "Map of Debian VMs to deploy"
  type = map(object({
    desc         = string
    cpu_cores    = number
    memory_mb    = number
    disk_size_gb = number
    ipv4_address = string
    ipv4_gateway = string
    tags         = string
  }))
  default = {}
}

variable "ssh_public_keys" {
  description = "List of public SSH keys to inject"
  type        = list(string)
  default     = []
}
