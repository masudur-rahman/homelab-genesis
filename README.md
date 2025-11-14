# 🚀 HomeLab Genesis (Proxmox + Terraform)

This repository contains the complete Infrastructure as Code (IaC) for my Proxmox homelab. The core principle here is **full automation**—the entire environment is defined, provisioned, and managed by Terraform. No manual intervention. This ensures the lab is 100% reproducible, stable, and can be rebuilt or modified with confidence.

-----

## ✨ The Philosophy

The goal of `homelab-genesis` is to treat my homelab like a production environment. The core ideas:

* **Automate Everything:** No "clicking around" in the Proxmox UI. If it's not in Terraform, it doesn't exist.
* **Built to Rebuild:** The entire lab can be destroyed and brought back to life in minutes. This makes it fearless to test new things.
* **Keep it Modular:** Each VM type (Talos, Flatcar, etc.) is its own "Lego brick" (a Terraform module), so the setup is clean and easy to grow.
* **Data \> Logic:** The "what" (like *how many* VMs) lives in `.tfvars` files. The "how" (the build logic) lives in the modules.

-----

## 🛠️ The Tech Stack

* **Virtualization:** Proxmox VE
* **IaC:** Terraform
* **The Provider:** `bpg/proxmox` (it's actively maintained and works well)
* **The "Lego Bricks" (VMs):**
    * Talos OS (for Kubernetes)
    * Flatcar Container Linux (for container-only stuff)
    * Debian (for everything else)
* **Provisioning:** Good ol' Cloud-Init and Butane

-----

## 🏗️ How It's Structured

This layout is designed to be clean, scalable, and easy to understand.

```
/homelab-genesis/
|
|-- main.tf             # The main entrypoint. Connects providers & calls modules.
|-- variables.tf        # Global variables (like API credentials).
|-- terraform.tfvars    # 🤫 My secrets! (In .gitignore, of course).
|-- pools.tf            # Defines the Proxmox Resource Pools (e.g., "prod" & "dev").
|-- .gitignore          # The list of files to ignore.
|
|-- 📁 vars/             # This is "what to build."
|   |-- 00-proxmox-host.tfvars    # Host details (which node, storage, etc.)
|   |-- 01-cluster-talos.tfvars   # Defines my Talos K8s cluster.
|   |-- 02-cluster-flatcar.tfvars # Defines my Flatcar VMs.
|   `-- 03-apps-debian.tfvars     # Defines my general-purpose Debian VMs.
|
|-- 📁 templates/          # This is "how to configure the VMs."
|   |-- talos-control-plane.bu.tftpl  # Butane template for Talos control plane.
|   |-- talos-worker.bu.tftpl         # Butane template for Talos workers.
|   |-- flatcar.bu.tftpl              # Butane template for Flatcar.
|   `-- debian-cloudinit.yml.tftpl    # Cloud-Init for Debian.
|
`-- 📁 modules/            # This is "how to build the VMs."
    |-- proxmox-talos-vm/     # The "Lego brick" for building one Talos VM.
    |   |-- main.tf
    |   |-- variables.tf
    |   `-- outputs.tf
    |
    |-- proxmox-flatcar-vm/   # The "Lego brick" for one Flatcar VM.
    |   `-- ...
    |
    `-- proxmox-debian-vm/    # The "Lego brick" for one Debian VM.
        `-- ...
```

-----

## 🚀 Getting Started

### What You'll Need

* A running Proxmox VE 8.x server.
* Terraform (I'm using v1.6+).
* A Proxmox API Token (with permissions for VMs, storage, etc.).
* The OS templates (Talos, Flatcar, Debian Cloud-Init) uploaded to Proxmox.

-----

### 1\. Clone It

```bash
git clone <your-repo-url>
cd homelab-genesis
```

-----

### 2\. Set Up Your Secrets

Terraform needs to log in. Create a `terraform.tfvars` file (it's already in `.gitignore`, so you won't accidentally commit it).

```hcl
# terraform.tfvars
pm_api_url   = "https://proxmox.example.com:8006/api2/json"
pm_api_token_id     = "terraform@pve!my-token"
pm_api_token_secret = "your-secret-uuid"
```

-----

### 3\. Tell Terraform About Your Host

Create `vars/00-proxmox-host.tfvars` to point to your specific Proxmox setup.

```hcl
# vars/00-proxmox-host.tfvars
proxmox_host_node = "pve"        # The name of your Proxmox node
storage_pool_vms  = "local-zfs"  # Where to put the VM disks
storage_pool_iso  = "local"      # Where to find your ISOs/templates
```

-----

### 4\. Define Your VMs

The files in `vars/` are where you decide what to build. This keeps your main files clean.

**Example: `vars/01-cluster-talos.tfvars`**

```hcl
talos_control_plane_count = 3
talos_worker_count        = 2

talos_vm_defaults = {
  disk_size_gb = 20
  memory_mb    = 2048
  vcpu_count   = 2
}
```

**Example: `vars/03-apps-debian.tfvars`**

```hcl
debian_vm_count = 4

debian_vm_defaults = {
  memory_mb  = 2048
  vcpu_count = 2
}
```

-----

## ⚡ Let's Run It\!

### Initialize

This downloads the Proxmox provider.

```bash
terraform init
```

### Plan

This shows you *what* Terraform is about to do. Notice we have to pass in the `.tfvars` files.

```bash
terraform plan \
  -var-file="vars/00-proxmox-host.tfvars" \
  -var-file="vars/01-cluster-talos.tfvars"
```

### Apply

This is the fun part.

```bash
terraform apply \
  -var-file="vars/00-proxmox-host.tfvars" \
  -var-file="vars/01-cluster-talos.tfvars"
```

> **Heads Up:** Terraform doesn't auto-load `.tfvars` files from subfolders. You always have to pass them in with the `-var-file` flag, which is actually great for controlling *what* you deploy.

-----

## 🌱 How to Grow This Lab

Want to add a new group of VMs (like for monitoring)?

1.  Create a new `04-monitoring-vms.tfvars` file in `vars/`.
2.  Add a new `module "monitoring_vms" { ... }` block in `main.tf` that uses your new file and re-uses an existing module (like `proxmox-debian-vm`).

The whole setup is built to scale this way.

-----

## 🌟 The Payoff

* Your entire lab is defined in code and backed up in Git.
* No more "configuration drift" or wondering *why* you made a change.
* You get a repeatable, idempotent setup.
* It's a clean, extendable foundation.