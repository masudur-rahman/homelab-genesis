terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.89.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_endpoint
  api_token = var.pm_api_token
  insecure  = var.pm_insecure

  ssh {
    agent = true
  }
}

data "proxmox_virtual_environment_version" "pm_version" {}
