# Homelab Genesis — Roadmap & Improvement Plan

Status snapshot: 2026-05-06. Repo = Terraform monorepo provisioning Proxmox VMs + 1 Talos K8s cluster (`olympus`) + addons (Cilium, Proxmox CSI). Workspaces split `infra` / `compute`. Plan below = gap analysis + phased implementation roadmap.

---

## 1. Current State (what exists)

| Area | Status | Notes |
|---|---|---|
| Proxmox VM provisioning (Debian) | done | `vm-standard` module, cloud-init, 4 prod VMs |
| Gateway/VPN (Debian) | done | `infra` workspace, 2 VMs |
| Talos cluster (`olympus`) | done | 3 CP + 2 worker, VIP, Image Factory |
| Cilium CNI | done | TLS via `tls` provider, Hubble certs, kube-proxy replacement |
| Proxmox CSI | done | Helm via `local-exec`, separate token |
| metrics-server + cert-approver | done | inline `extraManifests` |
| SOPS-encrypted secrets | done | `vars/secrets.enc.json` ↔ `vars/secrets.tfvars` |
| Flatcar module | stub | code exists, tfvars commented out |
| Bootstrap (image fetch) | done | Debian QCOW2 + Talos Image Factory ISO |
| Resource pool mgmt | done | `structure` module |

---

## 2. Gap Analysis (what missing / weak)

### 2.1 Infrastructure (Terraform / Proxmox)

| Gap | Impact | Severity |
|---|---|---|
| No CI/CD (lint, validate, plan-on-PR) | drift, broken commits | high |
| No `tflint` / `tfsec` / `checkov` | sec issues slip in | high |
| No pre-commit hooks (`fmt`, `validate`) | inconsistent code | med |
| Storage hardcoded `local-zfs` | no shared/NFS option | med |
| Bridge hardcoded `vmbr0`, no VLAN | no network segmentation | med |
| No MAC pinning | DHCP reservation breaks on rebuild | low |
| No image checksum verify on download | supply-chain risk | med |
| Single Proxmox node assumed | no HA / multi-node | low (homelab) |
| `templates/.gitkeep` legacy dir empty | dead code | low |
| `GEMINI.md` + `CLAUDE.md` parallel docs | duplication | low |

### 2.2 Talos / Kubernetes

| Gap | Impact | Severity |
|---|---|---|
| Addons via `local-exec helm` | TF can't detect drift; no diff; fragile | **high** |
| No GitOps (Flux/ArgoCD) | manual app deploys, no rollback | **high** |
| No LB controller (MetalLB / kube-vip / Cilium L2) | `.150–.179` LB pool reserved but unused | **high** |
| No ingress controller (Traefik / Nginx / Cilium Gateway) | nothing exposed in-cluster yet | **high** |
| No cert-manager | TLS for services manual | high |
| No external-dns | DNS records manual | med |
| No sealed-secrets / ESO / SOPS-in-cluster | no in-cluster secret pattern | high |
| No etcd backup / Velero | DR impossible | **high** |
| No monitoring (kube-prometheus-stack, Loki, Tempo) | observability gap on cluster | high |
| No Talos config drift detection | cluster drifts silently | med |
| No Talos / k8s upgrade runbook | manual + risky | med |
| Cert rotation (Talos PKI, Cilium CA) not automated | 3y certs expire silently | med |
| Single cluster only; multi-cluster blocks reserved but untested | unknown breakage on second cluster | med |
| Worker `node_taints` typed but not used | dead config | low |

### 2.3 Secrets / Security

| Gap | Impact | Severity |
|---|---|---|
| `files/secrets/*.yaml` (kubeconfig, talosconfig) plaintext on disk | leak risk | **high** |
| Cilium Hubble CA private key in `local_file` (Helm values, base64) | sensitive in TF state | high |
| Proxmox CSI token in Helm values file on disk | leak risk | med |
| No `sensitive = true` audit on outputs | secrets may print to logs | med |
| No state encryption (state in `states/` local) | secrets at rest unprotected | **high** |
| No SOPS for kubeconfig / talosconfig | inconsistent w/ secrets policy | med |
| No SSH key rotation procedure | stale keys accumulate | low |

### 2.4 Operations / Lifecycle

| Gap | Impact | Severity |
|---|---|---|
| No backup of TF state | rebuild from scratch on loss | **high** |
| No rebuild runbook | "built to rebuild" claim unverified | high |
| No DR test cadence | first failure = first test | high |
| No upgrade matrix doc (Talos→K8s→Cilium→CSI compat) | upgrade breaks | med |
| No `make destroy` safety guard | fat-finger nukes prod | high |
| No telemetry on apply (slack/discord notify) | silent runs | low |
| No cost / resource accounting (RAM/CPU usage per pool) | overcommit risk on 32GB host | med |

### 2.5 Documentation

| Gap | Impact | Severity |
|---|---|---|
| README current-status drifts from code | misleading | med |
| No per-module READMEs | onboarding friction | med |
| No `docs/` dir (architecture, runbooks, ADRs) | tribal knowledge | high |
| No diagram (network / cluster topology) | mental model hard | med |
| No upgrade guide (Talos / K8s minor bumps) | manual recall | med |
| Flatcar planned vs present module — unclear status | confusion | low |
| `CLAUDE.md` ≠ `GEMINI.md` content | maintenance burden | low |

### 2.6 Workloads (the "why" of the cluster)

| Gap | Impact | Severity |
|---|---|---|
| No app definitions in repo (or sibling repo linked) | cluster sits empty | high |
| No namespace / RBAC bootstrap | all-default-namespace pattern | med |
| No PVC examples using Proxmox CSI | CSI untested in real workload | med |
| No NetworkPolicy examples (Cilium has it, unused) | flat L3 in cluster | low |
| No HPA / VPA / resource quotas | noisy-neighbor risk | low |

---

## 3. Implementation Roadmap (phased)

Each phase = 1 logical change set → build/test → review → commit. Per project rule: **never implement multiple phases at once**.

### Phase 1 — Foundation hardening (no functional change)

Goal: lock quality gates before adding more surface area.

- 1.1 Add `.pre-commit-config.yaml` with: `terraform_fmt`, `terraform_validate`, `terraform_tflint`, `terraform_tfsec`, `terraform_docs`, `check-merge-conflict`, `detect-private-key`.
- 1.2 Add GitHub Actions (or local act):
  - `pr.yaml`: fmt-check, validate, tflint, tfsec, plan (using mock vars or `-refresh=false -lock=false`).
  - `release.yaml`: tag → render docs.
- 1.3 Add `tflint` config (`.tflint.hcl`) with bpg-proxmox + terraform-aws-rules disabled, generic ruleset enabled.
- 1.4 Encrypt local state: switch backend to local + `terraform_remote_state` + sops-wrapped state, OR move to remote backend (Terraform Cloud free tier / S3+KMS / MinIO+age).
- 1.5 Encrypt `files/secrets/*.yaml` via SOPS; decrypt-on-demand make target.
- 1.6 Mark all sensitive outputs `sensitive = true`.
- 1.7 Delete dead `templates/.gitkeep`, reconcile `GEMINI.md` ↔ `CLAUDE.md`.

Test: `make fmt && make validate && pre-commit run -a`.

### Phase 2 — Replace `local-exec` helm with declarative providers

Goal: addons become real TF resources w/ drift detection.

- 2.1 Add `helm` + `kubernetes` + `kubectl` providers to `talos-addons`.
  - Provider auth from `talos_cluster_kubeconfig.admin.kubernetes_client_configuration` (no kubeconfig file needed at provider init).
- 2.2 Replace `terraform_data.cilium_install` → `helm_release.cilium`.
- 2.3 Replace `terraform_data.csi_install` → `helm_release.proxmox_csi` + `kubernetes_namespace.csi_proxmox` w/ PSA labels.
- 2.4 Drop `terraform_data.wait_for_api`; rely on provider's retry + explicit `depends_on`.
- 2.5 Keep `local_file` Helm values only as audit artifact (or drop; pass values inline via `set { }` / `values = [yamlencode(...)]`).

Caveat: helm provider init w/ unreachable API blocks plan. Mitigate w/ `experiments` or two-stage apply (`-target=module.vm_talos` first, then full).

Test: `make destroy env=compute && make apply env=compute` clean rebuild.

### Phase 3 — LB + ingress + cert-manager + external-dns

Goal: turn `.150–.179` reserved range into real L4/L7 entry.

- 3.1 Cilium L2 announcements (already have Cilium; enable `l2announcements` + IP pool CRD `.150–.169` fixed, `.170–.179` dynamic). No MetalLB needed.
- 3.2 Install ingress: Cilium Gateway API (preferred — already shipping Cilium) OR Traefik via Helm.
- 3.3 cert-manager via `helm_release` + ClusterIssuer (Let's Encrypt DNS-01 via Cloudflare or self-signed if homelab-only).
- 3.4 external-dns → AdGuard at `10.66.0.253` (RFC2136) or Cloudflare for public zone.
- 3.5 Reserve `.50` ingress VIP doc → make it the GatewayClass IP.

Test: deploy hello-world `Service` type=LoadBalancer → IP assigned, DNS resolves, TLS from cert-manager.

### Phase 4 — GitOps: Flux v2 (or Argo CD)

Goal: stop deploying apps via Terraform. Cluster pulls from Git.

- 4.1 Bootstrap Flux (`helm_release` or `flux_bootstrap_git`) into namespace `flux-system`.
- 4.2 New repo (or `apps/` subdir of this repo) w/ `clusters/olympus/` Kustomizations.
- 4.3 Move addons from TF to Flux gradually: only **infrastructure-critical** addons (CNI, CSI, ingress, cert-manager) stay in TF. Apps + monitoring + Velero → Flux.
- 4.4 Add `kustomize-controller` SOPS decryption (age key bootstrapped via TF Secret).

Boundary rule: TF owns **cluster existence + must-exist-before-pods-can-run** addons. Flux owns everything else.

Test: kill an app deploy → Flux reconciles back.

### Phase 5 — Observability

- 5.1 Deploy `kube-prometheus-stack` via Flux.
- 5.2 Loki + Promtail (or Alloy) for logs.
- 5.3 Hubble UI exposed via ingress (TLS, basic auth).
- 5.4 Grafana dashboards: Talos node, Cilium, Proxmox CSI volumes, Proxmox host (via `node_exporter` outside cluster on Proxmox host).
- 5.5 Alertmanager → ntfy/Discord/email.

### Phase 6 — Backup / DR

- 6.1 Velero w/ MinIO (deploy MinIO on Debian VM or external S3).
- 6.2 Schedule: daily full, hourly incremental for `*/data` namespaces.
- 6.3 Talos `etcd` snapshot cron (talosctl `etcd snapshot`) → MinIO.
- 6.4 Document **restore drill** runbook; test quarterly.
- 6.5 Backup Terraform state daily.

### Phase 7 — Secret management in-cluster

- 7.1 External Secrets Operator (ESO) → Vault / Bitwarden / 1Password / SOPS.
  - For homelab: SOPS + age via Flux `kustomize-controller` (simplest).
- 7.2 Rotate Cilium CA + Hubble certs: shorten validity 26280h → 8760h, add `time_rotating` resource.
- 7.3 Rotate Talos PKI: document `talosctl gen secrets` rotation procedure.

### Phase 8 — Multi-cluster validation

- 8.1 Stand up second cluster (`hades` at `.80–.99`) using same module.
- 8.2 Find collisions: Helm release names, file paths (`files/helm/*-cilium-values.yaml` already cluster-scoped — good), TLS resource names.
- 8.3 Add cluster-mesh (Cilium ClusterMesh) doc + provision optional.

### Phase 9 — Flatcar (only if actually needed)

- 9.1 Decide use case: Docker Swarm? K3s? Single-node container host?
- 9.2 If no real workload → **delete `vm-flatcar` module** (YAGNI).
- 9.3 If kept: finish Ignition template, test, document.

### Phase 10 — Network/storage flexibility

- 10.1 Parameterize `bridge` + add VLAN tag support in all VM modules.
- 10.2 Parameterize `datastore_id` (allow `local-lvm`, NFS, Ceph).
- 10.3 Optional: add second Proxmox node support (multi-`node_name`).

---

## 4. Best-Practice Implementation Details

### 4.1 Module structure (target)

```
modules/
├── bootstrap/              # image fetch
├── structure/              # pools, resource hierarchy
├── vm-standard/            # generic Debian
├── vm-flatcar/             # (or delete)
├── talos-cluster/          # composite: VMs + secrets + addons
│   ├── vm-talos/           # Proxmox VMs + machine config apply
│   ├── talos-addons/       # CNI + CSI + Gateway + cert-manager
│   └── talos-bootstrap/    # NEW: Flux/ESO bootstrap (one-shot)
└── lb-network/             # NEW: Cilium L2 IPPool CRDs
```

### 4.2 Provider strategy

- TF providers: `bpg/proxmox`, `siderolabs/talos`, `helm`, `kubernetes`, `kubectl`, `tls`, `sops`, `local`, `time`.
- Auth from `talos_cluster_kubeconfig.admin.kubernetes_client_configuration` — never read kubeconfig file in provider blocks (file may not exist on first apply).

```hcl
provider "helm" {
  alias = "olympus"
  kubernetes {
    host                   = data.talos_cluster_kubeconfig.admin.kubernetes_client_configuration.host
    client_certificate     = base64decode(data.talos_cluster_kubeconfig.admin.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(data.talos_cluster_kubeconfig.admin.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(data.talos_cluster_kubeconfig.admin.kubernetes_client_configuration.ca_certificate)
  }
}
```

### 4.3 Helm release pattern (replaces `local-exec`)

```hcl
resource "helm_release" "cilium" {
  provider   = helm.olympus
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"
  values     = [templatefile("${path.module}/templates/cilium-values.yaml.tftpl", { ... })]
  wait       = true
  timeout    = 600
}
```

### 4.4 Secrets at rest

- All `files/secrets/*` MUST be SOPS-encrypted. Add to `.sops.yaml`:
  ```yaml
  creation_rules:
    - path_regex: files/secrets/.*
      age: <pubkey>
  ```
- Pre-commit hook: reject plaintext secrets via `gitleaks` or `trufflehog`.

### 4.5 State

- Move `states/` → remote backend (S3+DynamoDB / Terraform Cloud / GitLab managed / minio+postgres lock).
- If staying local: encrypt at rest (LUKS / FileVault — already on macOS) + git-crypt the `states/` dir → no, **never commit state**, even encrypted.

### 4.6 GitOps boundary

```
Terraform owns:                  Flux owns:
- VMs                            - Apps
- Talos config                   - Monitoring stack
- Cilium                         - Velero
- CSI                            - cert-manager configs (Issuers)
- Ingress controller             - Hubble UI exposure
- cert-manager (chart)           - external-dns configs
- Flux itself (bootstrap)        - All Namespaces (except kube-system / flux-system / csi-proxmox)
```

### 4.7 Naming + labels

- Tags: `<workspace>`, `<os>`, `<role>`, `<cluster>`. Already partially done.
- Node labels: include `topology.kubernetes.io/region` + `zone` (already done in machine-config template).
- Add `talos.dev/owned-by-tf=true` annotation to all nodes for clarity.

### 4.8 Versioning + upgrades

- Pin chart versions (already done via `var.cilium_version`).
- Add `versions.tfvars` central file: Talos, K8s, Cilium, CSI, cert-manager, Traefik, Flux versions.
- Document compat matrix in `docs/upgrades.md`. Source: Talos release notes + Cilium support matrix.
- Upgrade flow: bump `versions.tfvars` → PR → CI plan → apply on branch cluster → merge.

---

## 5. Documentation Plan

Create `docs/` with:

| File | Purpose |
|---|---|
| `docs/architecture.md` | Block diagram, module graph, data flow |
| `docs/network.md` | IP plan (move from README), VLAN plan, DNS |
| `docs/secrets.md` | SOPS workflow, age key mgmt, rotation |
| `docs/runbooks/rebuild.md` | Full lab destroy + recreate, ETA, gotchas |
| `docs/runbooks/upgrade-talos.md` | minor + major Talos bumps |
| `docs/runbooks/upgrade-k8s.md` | K8s minor upgrade w/ Cilium compat check |
| `docs/runbooks/cert-rotation.md` | Talos PKI + Cilium CA rotation |
| `docs/runbooks/disaster-recovery.md` | etcd loss, control-plane loss, host loss |
| `docs/runbooks/backup-restore.md` | Velero restore drill |
| `docs/adr/0001-talos-vs-k3s.md` | Architecture Decision Records |
| `docs/adr/0002-helm-via-tf-vs-flux.md` | Why TF for infra addons, Flux for apps |
| `docs/adr/0003-cilium-vs-other-cni.md` | |
| `docs/upgrades.md` | Version compat matrix |
| `modules/<name>/README.md` | Per-module: inputs/outputs/example (auto-gen via `terraform-docs`) |

External references to bookmark:
- Talos docs: https://www.talos.dev/v1.12/
- Cilium Talos guide: https://docs.cilium.io/en/stable/installation/k8s-install-helm/#talos-linux
- bpg/proxmox: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
- Proxmox CSI: https://github.com/sergelogvinov/proxmox-csi-plugin
- FluxCD bootstrap: https://fluxcd.io/flux/installation/bootstrap/
- ESO: https://external-secrets.io/

---

## 6. Quick wins (≤ 1 day each, do first)

1. Add `.pre-commit-config.yaml` + run on existing tree.
2. SOPS-encrypt `files/secrets/*`.
3. Replace `terraform_data` helm with `helm_release` (Phase 2.1–2.3).
4. Mark `kubeconfig` / `talosconfig` outputs `sensitive = true`.
5. Delete `templates/.gitkeep`, reconcile `GEMINI.md`.
6. Add `versions.tfvars` central pin file.
7. Per-module `README.md` via `terraform-docs`.
8. Add `make destroy` confirmation prompt.

---

## 7. Risks / Open questions

- **Helm provider + cluster bootstrap deadlock**: helm provider init fails if API unreachable → blocks plan. Solutions: (a) two-stage apply (`-target` first), (b) `lifecycle.precondition`, (c) keep `local-exec` only for first install, switch to `helm_release` after. Prefer (a) — already have `tf_targets` mechanism in Makefile.
- **Talos Cilium `kubeProxyReplacement: true` + L2 announcements**: validate Cilium version supports both. Already pinned — verify on upgrade.
- **Single Proxmox host = single point of failure**: out of scope for IaC; need second host for true HA. Roadmap separately.
- **State backend choice**: depends on whether user wants cloud dep or self-hosted. Decide before Phase 1.4.
- **GitOps repo split**: same repo (monorepo) vs separate apps repo. Recommend separate (`homelab-apps`) — different lifecycle, different reviewers.

---

## 8. Suggested execution order (next 4 sprints)

| Sprint | Phases | Deliverable |
|---|---|---|
| 1 | 1 + quick wins | green CI, encrypted secrets, sensitive outputs |
| 2 | 2 | declarative helm, no `local-exec` |
| 3 | 3 | working LB + ingress + TLS for first app |
| 4 | 4 + 5 (start) | Flux bootstrapped, monitoring deployed via Flux |

Phases 6–10 = ongoing / opportunistic.
