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
