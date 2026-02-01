terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
  }
}

# ----------------------------------

variable "pools" {
  description = "List of Resource Pools (Folders) to create"
  type        = list(string)
}

# ----------------------------------

resource "proxmox_virtual_environment_pool" "pool" {
  for_each = toset(var.pools)
  comment  = "Managed by Terraform (${terraform.workspace})"
  pool_id  = each.key
}

# ----------------------------------

output "pool_ids" {
  value = {
    for p in proxmox_virtual_environment_pool.pool : p.pool_id => p.id
  }
}
