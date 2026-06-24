# Project: homelab-genesis

## Overview
Terraform IaC for provisioning and managing Proxmox VMs in a homelab environment. Provisions Debian, Talos (K8s), and Flatcar Container Linux VMs with cloud-init/butane configuration.

## Stack
- IaC: Terraform >= 1.6.0
- Provider: bpg/proxmox ~> 0.93.0, siderolabs/talos 0.10.1
- VM OSes: Debian 12 (cloud-init), Talos OS (Image Factory), Flatcar (planned)
- Provisioning: Cloud-Init, Talos Image Factory
- Host: Proxmox VE 8.x on HP EliteBook (32GB RAM)

## Architecture
- `main.tf` / `variables.tf` / `outputs.tf` -- Root entrypoint, orchestrates modules
- `terraform.tf` -- Provider config, backend (local with workspaces)
- `modules/bootstrap/` -- Downloads base images (Debian QCOW2, Talos ISO)
- `modules/structure/` -- Creates Proxmox resource pools
- `modules/vm-standard/` -- Provisions Debian VMs with cloud-init
- `modules/vm-talos/` -- (stub) Talos K8s VM provisioning
- `modules/vm-flatcar/` -- (stub) Flatcar Container Linux provisioning
- `vars/` -- Environment-specific tfvars (common, infra, compute)
- `templates/` -- Cloud-init templates
- `states/` -- Local terraform state (workspace-based: infra, compute)

## Commands
```bash
make init              # terraform init
make workspace ENV=x   # switch/create workspace
make plan ENV=x        # terraform plan with env-specific tfvars
make apply ENV=x       # terraform apply
make destroy ENV=x     # terraform destroy
make fmt               # format .tf files
make validate          # validate syntax
```

## Conventions
- Workspaces separate environments: `infra` (gateways/VPN), `compute` (app VMs)
- VM definitions live in `vars/` tfvars files, logic in `modules/`
- Module naming: `vm-{os-type}` (vm-standard, vm-talos, vm-flatcar)
- All VMs on 10.66.0.0/24, IPs assigned via `ip_start + count.index`
- Resource pools group VMs logically (gateway, servers, compute)
- Cloud-init templates in module-local `templates/` directory

## Active Context

## Learned
- [state]: Use `terraform state rm -state=states/terraform.tfstate.d/{env}/terraform.tfstate {address}` if workspace selection fails to resolve state paths.
- [auth]: Proxmox provider requires SSH identities loaded in `ssh-agent` for authentication (`ssh-add <key_path>`).
- [talos]: `ens18` is only the Talos **config-layer altname** (AddressSpec) accepted in `machine.network.interfaces`. The **runtime kernel netdev is `eth0`** (AddressStatus) — verified on live olympus cluster. Anything matching real devices (Cilium L2 announcements `interfaces`, Cilium auto-detected `Devices: eth0`) must use `eth0`, NOT `ens18`. Verify with `talosctl -n <ip> get addresses` (LINK column) or `cilium-dbg status --verbose | grep Devices`.
- [talos]: Must use Image Factory nocloud installer image (`machine.install.image`) — generic installer creates `metal` boot assets, breaking NoCloud hostname/platform detection after install to disk.
- [talos]: Hostname on NoCloud comes from SMBIOS serial (`smbios { serial = "ds=nocloud;h=<name>" }`). Meta-data `local-hostname`/`hostname` fields are ignored in practice. `machine.network.hostname` in config is rejected on NoCloud platform.
- [cilium]: Talos 1.9+ requires specific Cilium Helm values (disabling `cgroup.autoMount`) and privileged `securityContext`.
- [cilium]: With `kubeProxyReplacement: true`, Cilium needs `k8sServiceHost`/`k8sServicePort` pointing to the cluster VIP to avoid bootstrap deadlock (can't reach ClusterIP `10.96.0.1` without CNI).
- [talos]: CSI inline manifests need an explicit Namespace resource before the Helm-rendered resources (`create_namespace` in `helm_template` only renders template, doesn't create at apply time).
- [talos]: kubelet needs `serverTLSBootstrap: true` in `machine.kubelet.extraConfig` for proper serving certs with IP SANs (required by metrics-server).
