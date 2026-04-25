# 🛠️ Project Genesis Makefile
.DEFAULT_GOAL := help

env ?= compute

export TF_DATA_DIR := states/.terraform

COMMON_VARS  := vars/common.tfvars
SECRETS_FILE := vars/secrets.tfvars
SECRETS_ENC  := vars/secrets.enc.json
SECRETS_JSON := vars/secrets.json
ENV_VAR_FILES := $(wildcard vars/$(env)/*.tfvars)
TF_VAR_ARGS := -var-file="$(COMMON_VARS)" -var-file="$(SECRETS_FILE)" $(foreach file,$(ENV_VAR_FILES),-var-file="$(file)")

# Per-env default -target gating. `infra` only runs vm_standard and its
# transitive dependencies (structure pools, bootstrap debian image);
# `compute` defaults to the full graph. Pass bare addresses (no -target=
# prefix), comma-separated for multiple. Override from terminal, e.g.:
#   make plan env=infra tf_targets='module.vm_flatcar'
#   make plan tf_targets='module.vm_standard,module.structure'
ifeq ($(env),infra)
tf_targets ?= module.vm_standard
endif

COMMA := ,
TF_TARGET_FLAGS := $(foreach t,$(subst $(COMMA), ,$(tf_targets)),-target=$(t))

cluster ?= homelab-k8s

.PHONY: help init init_reconfigure init_upgrade workspace encrypt decrypt plan apply refresh destroy fmt validate output kubeconfig talosconfig state_list state_rm

help: ## Show this help message
	@echo "Project Genesis — available make targets"
	@echo ""
	@echo "Usage: make <target> [env=infra|compute] [tf_targets='module.x,module.y'] [cluster=<name>] [addr=<tf-address>]"
	@echo ""
	@awk 'BEGIN {FS = ":[^#]*## "} /^[a-zA-Z_][a-zA-Z0-9_-]*:[^#]*## / {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform in states/
	@mkdir -p states
	@echo "🔧 Initializing Terraform into [states/]..."
	terraform init

init_reconfigure: ## Re-init Terraform with -reconfigure
	@mkdir -p states
	@echo "🔧 Initializing Terraform into [states/]..."
	terraform init -reconfigure

init_upgrade: ## Init Terraform with -upgrade
	@mkdir -p states
	@echo "🔧 Initializing Terraform into [states/]..."
	terraform init -upgrade

workspace: ## Select or create workspace for env
	@echo "🔀 Using environment: [$(env)]..."
	@terraform workspace select $(env) 2>/dev/null || terraform workspace new $(env)

# Encrypt: secrets.tfvars -> secrets.json (intermediate) -> secrets.enc.json
encrypt: ## Encrypt secrets.tfvars to secrets.enc.json (SOPS)
	@jq -Rn '[inputs | select(length > 0) | capture("^\\s*(?<key>\\S+)\\s*=\\s*\"(?<value>.*)\"$$")] | from_entries' $(SECRETS_FILE) > $(SECRETS_JSON)
	@sops --encrypt $(SECRETS_JSON) > $(SECRETS_ENC)
	@rm -f $(SECRETS_JSON)
	@echo "🔒 Secrets encrypted to $(SECRETS_ENC)"

# Decrypt: secrets.enc.json -> secrets.json (intermediate) -> secrets.tfvars
decrypt: ## Decrypt secrets.enc.json to secrets.tfvars (SOPS)
	@sops --decrypt $(SECRETS_ENC) > $(SECRETS_JSON)
	@jq -r 'to_entries[] | "\(.key) = \"\(.value)\""' $(SECRETS_JSON) > $(SECRETS_FILE)
	@rm -f $(SECRETS_JSON)
	@echo "🔓 Secrets decrypted to $(SECRETS_FILE)"

plan: workspace decrypt ## Terraform plan for env
	@echo "📋 Planning infrastructure for [$(env)]..."
	terraform plan $(TF_VAR_ARGS) $(TF_TARGET_FLAGS)

apply: workspace decrypt ## Terraform apply for env
	@echo "🚀 Applying changes to [$(env)]..."
	terraform apply $(TF_VAR_ARGS) $(TF_TARGET_FLAGS)

refresh: workspace decrypt ## Refresh state only for env
	@echo "🔄 Refreshing state for [$(env)]..."
	terraform apply -refresh-only $(TF_VAR_ARGS) $(TF_TARGET_FLAGS)

destroy: workspace decrypt ## Destroy env infrastructure
	@echo "🔥 DESTROYING $(env) Infrastructure..."
	terraform destroy $(TF_VAR_ARGS) $(TF_TARGET_FLAGS)

fmt: ## Format all .tf files recursively
	@echo "🧹 Formatting code..."
	terraform fmt -recursive

validate: ## Validate Terraform configuration
	@echo "✅ Validating configuration..."
	terraform init -backend=false # Validate needs providers present
	terraform validate

STATE_FILE := states/terraform.tfstate.d/$(env)/terraform.tfstate

state_list: workspace ## List resources in env state
	@terraform state list

state_rm: workspace ## Remove resource from env state (addr=module.xxx)
	@if [ -z "$(addr)" ]; then echo "Usage: make state_rm env=compute addr='module.xxx'"; exit 1; fi
	@echo "Removing $(addr) from $(env) state..."
	@terraform state rm -state="$(STATE_FILE)" '$(addr)'

output: workspace ## Show Terraform outputs for env
	terraform output

kubeconfig: workspace ## Export kubeconfig for cluster (cluster=<name>)
	@mkdir -p files/kubeconfigs
	@terraform output -raw talos_kubeconfigs | jq -r '.["$(cluster)"]' > files/kubeconfigs/$(cluster).yaml
	@echo "Kubeconfig → files/kubeconfigs/$(cluster).yaml"

talosconfig: workspace ## Export talosconfig for cluster (cluster=<name>)
	@mkdir -p files/secrets
	@terraform output -raw talos_talosconfigs | jq -r '.["$(cluster)"]' > files/secrets/$(cluster)_talosconfig.yaml
	@echo "Talosconfig → files/secrets/$(cluster)_talosconfig.yaml"
