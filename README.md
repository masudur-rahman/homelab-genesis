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
- **Providers:**
  - [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) ~> 0.93.0
  - [siderolabs/talos](https://registry.terraform.io/providers/siderolabs/talos/latest) 0.10.1
- **VM Types:**
  - Debian 12 (Cloud-Init) — gateways, app servers
  - Talos OS (Image Factory) — Kubernetes cluster
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
| `infra`   | Network infrastructure | 2x Gateway/VPN (Debian) |
| `compute` | Application workloads  | Debian app VMs + Talos K8s cluster(s) + Flatcar (planned) |

---

## Network / IP Allocation (10.66.0.0/24)

The entire homelab lives on a single flat `/24`. IPs are carved into fixed
blocks by service type so ranges never collide as things grow. This is the
authoritative reference for IP planning.

| Range            | Size | Purpose                                | Notes                                           |
|------------------|------|----------------------------------------|-------------------------------------------------|
| `.1`             | 1    | Router (fixed)                         |                                                 |
| `.2`–`.4`        | 3    | Reserved — network gear                |                                                 |
| `.5`–`.9`        | 5    | VPN / gateway VMs                      | `infra` workspace (currently `.5`, `.6`)        |
| `.10`            | 1    | Proxmox host (fixed)                   |                                                 |
| `.11`–`.19`      | 9    | Reserved — infra growth                |                                                 |
| `.20`–`.29`      | 10   | Debian — data / storage tier           | `data-01 = .20`                                 |
| `.30`–`.39`      | 10   | Debian — application servers           | `expense-tracker-01 = .30`                      |
| `.40`–`.49`      | 10   | Debian — monitoring / observability    | `monitoring-01 = .40`                           |
| `.50`            | 1    | Ingress VIP (reserved for HA)          |                                                 |
| `.51`–`.59`      | 9    | Debian — edge / ingress VMs            | `portal-01 = .51`                               |
| `.60`–`.79`      | 20   | Talos cluster #1 (`olympus`)           | `.60` VIP · `.61`–`.69` CPs · `.70`–`.79` wkrs  |
| `.80`–`.99`      | 20   | Talos cluster #2 (future)              | same per-block layout                           |
| `.100`–`.119`    | 20   | Talos cluster #3 (future)              | same per-block layout                           |
| `.120`–`.129`    | 10   | Flatcar / container VMs                |                                                 |
| `.130`–`.149`    | 20   | Reserved floating                      | CSI floating, extra VM types, misc              |
| `.150`–`.169`    | 20   | K8s LoadBalancer pool (cl #1 `olympus`)| auto-assigned; pin via `lbipam.cilium.io/ips`   |
| `.170`–`.179`    | 10   | Reserved — future LB / per-cluster     | unused                                          |
| `.180`–`.229`    | 50   | Router DHCP (regular + guest network)  |                                                 |
| `.230`–`.249`    | 20   | Reserved — expansion                   |                                                 |
| `.250`–`.252`    | 3    | Reserved                               |                                                 |
| `.253`           | 1    | AdGuard DNS (fixed)                    |                                                 |
| `.254`           | 1    | Reserved                               |                                                 |

**Talos per-cluster block layout** (20 IPs each): first IP is the cluster VIP,
next 9 for control-plane nodes (max 5 used in practice), next 10 for workers.

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

### Implemented — `infra` workspace
- 2x Gateway/VPN (Debian, 1GB RAM, 1 vCPU, 8GB disk)

### Implemented — `compute` workspace
- 1x Portal          (Debian, 2GB RAM, 2 vCPU, 32GB disk)  — ingress/proxy
- 1x Data            (Debian, 8GB RAM, 4 vCPU, 100GB disk) — postgres/redis
- 1x Expense-tracker (Debian, 2GB RAM, 2 vCPU, 20GB disk)
- 1x Monitoring      (Debian, 4GB RAM, 2 vCPU, 50GB disk)  — prometheus/grafana/loki
- `olympus` Talos K8s cluster: 3x control plane + 2x worker (Cilium CNI, Proxmox CSI)

### Planned
- Additional Talos clusters (blocks reserved in IP plan)
- Flatcar Container Linux VMs

---

## Adding New VMs

1. Add VM definitions to the appropriate `vars/<workspace>/*.tfvars` file
2. If needed, add a new `module` block in `main.tf`
3. Run `make plan ENV=<workspace>` to preview, then `make apply ENV=<workspace>`
