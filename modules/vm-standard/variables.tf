variable "proxmox_node" { type = string }
variable "name" { type = string }
variable "desc" { type = string }
variable "vm_count" { type = number }
variable "tags" {
  description = "Tags for the VMs"
  type        = list(string)
}
variable "cpu" { type = number }
variable "memory" { type = number }
variable "disk" { type = number }
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

variable "pool_gateway" {
  type    = string
  default = null
}
variable "pool_cidr" {
  type    = string
  default = null
}
