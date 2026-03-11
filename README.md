# HomeLab Genesis (Proxmox + Terraform)

Terraform IaC for provisioning and managing Proxmox VMs in a homelab environment. The entire environment is defined, provisioned, and managed by Terraform — no manual intervention.

---

## Philosophy

- **Automate Everything:** No "clicking around" in the Proxmox UI. If it's not in Terraform, it doesn't exist.
- **Built to Rebuild:** The entire lab can be destroyed and brought back to life in minutes.
- **Keep it Modular:** Each VM type (Debian, Talos, Flatcar) is its own Terraform module.
- **Data > Logic:** The "what" (VM counts, specs) lives in `.tfvars` files. The "how" (build logic) lives in the modules.

---

## Tech Stack

- **Virtualization:** Proxmox VE 8.x (HP EliteBook, 32GB RAM)
- **IaC:** Terraform >= 1.6.0
- **Provider:** [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) ~> 0.93.0
- **VM Types:**
  - Debian 12 (Cloud-Init) — gateways, app servers
  - Talos OS (Image Factory) — Kubernetes cluster (planned)
  - Flatcar Container Linux — lightweight containers (planned)

---

## Project Structure

```
homelab-genesis/
|
|-- main.tf              # Root entrypoint, calls all modules
|-- variables.tf         # Global input variables
|-- outputs.tf           # Root outputs (per-module VM details)
|-- terraform.tf         # Provider & backend config (local + workspaces)
|-- Makefile             # Workflow commands (init, plan, apply, destroy)
|
|-- vars/                # Environment-specific variable files
|   |-- common.tfvars           # Shared settings (Proxmox host, storage, network)
|   |-- infra/
|   |   `-- gateways.tfvars     # Gateway/VPN VM definitions
|   `-- compute/
|       |-- settings.tfvars     # Compute workspace settings
|       |-- debian.tfvars       # Debian app VM definitions
|       |-- talos.tfvars        # Talos K8s cluster config (WIP)
|       `-- flatcar.tfvars      # Flatcar VM config (WIP)
|
|-- modules/
|   |-- bootstrap/       # Downloads base images (Debian QCOW2, Talos ISO)
|   |-- structure/       # Creates Proxmox resource pools
|   |-- vm-standard/     # Provisions Debian VMs with cloud-init
|   |-- vm-talos/        # (stub) Talos K8s VM provisioning
|   `-- vm-flatcar/      # (stub) Flatcar Container Linux provisioning
|
|-- templates/           # Root-level cloud-init templates (legacy)
`-- states/              # Local terraform state (workspace-based)
```

---

## Workspaces

Terraform workspaces separate environments:

| Workspace | Purpose | VMs |
|-----------|---------|-----|
| `infra` | Network infrastructure | Gateway/VPN (2x Debian, 1GB/1vCPU) |
| `compute` | Application workloads | Portal (2GB/2vCPU), Data (8GB/4vCPU), Expense-tracker (2GB/2vCPU) |

---

## Getting Started

### Prerequisites

- Proxmox VE 8.x server
- Terraform >= 1.6.0
- Proxmox API Token with VM/storage permissions

### 1. Clone & Initialize

```bash
git clone <repo-url>
cd homelab-genesis
make init
```

### 2. Set Up Secrets

Create `terraform.tfvars` (already in `.gitignore`):

```hcl
proxmox_api_url    = "https://proxmox.example.com:8006/api2/json"
proxmox_api_token  = "terraform@pve!my-token=your-secret-uuid"
```

### 3. Plan & Apply

```bash
# Infrastructure (gateways)
make plan ENV=infra
make apply ENV=infra

# Compute (app VMs)
make plan ENV=compute
make apply ENV=compute
```

---

## Makefile Commands

```bash
make init              # terraform init
make workspace ENV=x   # switch/create workspace
make plan ENV=x        # terraform plan with env-specific tfvars
make apply ENV=x       # terraform apply
make refresh ENV=x     # refresh state only
make destroy ENV=x     # terraform destroy
make fmt               # format .tf files recursively
make validate          # validate configuration
make output ENV=x      # show outputs
```

---

## Current Status

### Implemented (5 VMs)
- 2x Gateway/VPN (Debian, 1GB RAM, 1 vCPU, 8GB disk) — `infra` workspace
- 1x Portal (Debian, 2GB RAM, 2 vCPU, 32GB disk) — `compute` workspace
- 1x Data (Debian, 8GB RAM, 4 vCPU, 100GB disk) — `compute` workspace
- 1x Expense-tracker (Debian, 2GB RAM, 2 vCPU, 20GB disk) — `compute` workspace

### Planned
- 3x Talos OS control plane nodes (K8s)
- 2x Talos OS worker nodes (K8s)
- 2x Flatcar Container Linux VMs
- 1x Monitoring/utility VM

---

## Adding New VMs

1. Add VM definitions to the appropriate `vars/<workspace>/*.tfvars` file
2. If needed, add a new `module` block in `main.tf`
3. Run `make plan ENV=<workspace>` to preview, then `make apply ENV=<workspace>`
