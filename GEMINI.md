# Gemini Project Instructions: homelab-genesis

This document contains foundational mandates and operational workflows for this project. These instructions take absolute precedence over general defaults.

## 1. Strict Workflow (Foundational)
Adhere to this workflow for ALL changes:
1. **Ask:** Ask targeted questions BEFORE coding (max 1 round).
2. **Plan:** Outline the implementation plan before making any changes.
3. **Approve:** Wait for explicit user approval of the plan.
4. **Implement:** Code the approved plan using surgical edits.
5. **Test:** Run validation/tests and report pass/fail immediately.
6. **Review:** Perform a self-review of the changes.
7. **Remember:** Append learnings to the ## Learned section in GEMINI.md.

## 2. Development Process & Agent Logic

### Phase 1: Planning (Planner Logic)
- **Objective:** Identify all necessary changes and risks before implementation.
- **Rules:** 
  - Max 10 file changes per plan.
  - Flag ambiguities as questions for the user.
  - Check existing patterns (e.g., in modules/) before suggesting new ones.
  - Output format: Questions -> Changes (path - what + why) -> Tests Needed.

### Phase 2: Implementation & Refactoring (Refactorer Logic)
- **Objective:** Execute approved changes or improve existing structure.
- **Rules:**
  - One refactor at a time; never mix refactoring with feature work.
  - All existing tests must pass after a refactor.
  - Write tests FIRST if they don't exist before refactoring.
  - Preserve public APIs unless a change is explicitly requested.

### Phase 3: Review (Reviewer Logic)
- **Objective:** Verify quality, security, and consistency.
- **Rules:**
  - Run git diff to see all changes.
  - Check against Section 3 (Engineering Standards).
  - Focus on: Type safety, security (leaked secrets), and naming consistency.

## 3. Engineering Standards (Terraform/HCL)
- **Module Responsibility:** Each module has a single responsibility (one VM type or one infra concern).
- **Size Limits:** No resource block > 50 lines; no file > 300 lines.
- **Documentation:** All variables and outputs MUST have description fields.
- **HCL Best Practices:**
  - No hardcoded values; use variables or locals.
  - Use for_each over count when keys are meaningful (e.g., VM names).
  - Use validation blocks for variable constraints (e.g., memory >= 512).
  - Mark sensitive values (tokens, passwords) with sensitive = true.

## 4. Validation & Testing
- **Mandatory Commands:**
  - Run terraform validate after any structural change.
  - Run terraform plan to verify resource changes before application.
  - Use make fmt for consistent formatting.
- **Verification:**
  - Check terraform plan for unexpected destroys/recreates.
  - Verify cloud-init template rendering with terraform console when modifying templates.

## 5. Project Memory & Maintenance
- **Updating Memory:** When a new pattern, command, or bug fix is identified, update the ## Learned section in GEMINI.md.
- **Format:** - [topic]: [what was learned] (keep to one line).
- **Discovery:** Read 2-3 similar files before creating new modules to ensure pattern consistency.

## 6. Project Context & Conventions
- **Stack:** Terraform >= 1.6.0, Proxmox 8.x, Debian/Talos/Flatcar.
- **Workspaces:** Use infra (gateways/VPN) and compute (app VMs) workspaces.
- **Networking:** All VMs on 10.66.0.0/24; IPs assigned via ip_start + count.index.
- **Structure:** Logic in modules/, definitions in vars/ tfvars, templates in module-local templates/.

## Learned
- [state]: Use terraform state rm -state=states/terraform.tfstate.d/{env}/terraform.tfstate {address} if workspace selection fails to resolve state paths.
- [auth]: Proxmox provider requires SSH identities loaded in ssh-agent for authentication (ssh-add <key_path>).
- [talos]: First network interface on Proxmox VMs with q35 is typically ens18 (VirtIO default).
- [cilium]: Talos 1.9+ requires specific Cilium Helm values (disabling cgroup.autoMount) and privileged securityContext.
- [talos]: Deadlock occurs if agent { enabled = true } is set in proxmox_virtual_environment_vm before config is applied.
- [helm]: Explicitly set kube_version in helm_template to avoid version incompatibility (default is 1.20.0).
- [talos]: Best way to provide initial IP/Config on Proxmox without DHCP is the initialization block with user_data_file_id pointing to a Talos config snippet (nocloud platform).
- [talos]: Use terraform_data with a destroy provisioner to run kubectl drain/delete before VM destruction for graceful node cleanup on scale-down.
