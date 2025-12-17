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

variable "common_gateway" {
  description = "Default Gateway IP (fallback if not defined in pool)"
  type        = string
}

variable "common_cidr" {
  description = "Default Network CIDR (fallback if not defined in pool)"
  type        = string
}

variable "ssh_public_keys" {
  description = "List of SSH public keys"
  type        = list(string)
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
