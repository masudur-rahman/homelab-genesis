terraform {
  required_version = ">= 1.6.0"

  backend "local" {
    path          = "states/terraform.tfstate"
    workspace_dir = "states/terraform.tfstate.d"
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.93.0"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

  }
}

provider "proxmox" {
  endpoint  = var.pm_api_endpoint
  api_token = var.pm_api_token
  insecure  = var.pm_insecure

  ssh {
    agent    = true
    username = "root"
  }
}

data "proxmox_virtual_environment_version" "pm_version" {}

