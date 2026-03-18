# 🛠️ Project Genesis Makefile
ENV ?= compute

export TF_DATA_DIR := states/.terraform

COMMON_VARS  := vars/common.tfvars
SECRETS_FILE := vars/secrets.tfvars
SECRETS_ENC  := vars/secrets.enc.json
SECRETS_JSON := vars/secrets.json
ENV_VAR_FILES := $(wildcard vars/$(ENV)/*.tfvars)
TF_VAR_ARGS := -var-file="$(COMMON_VARS)" -var-file="$(SECRETS_FILE)" $(foreach file,$(ENV_VAR_FILES),-var-file="$(file)")

CLUSTER ?= homelab-k8s

.PHONY: init plan apply destroy workspace fmt validate output init_reconfigure decrypt encrypt kubeconfig talosconfig

init:
	@mkdir -p states
	@echo "🔧 Initializing Terraform into [states/]..."
	terraform init

init_reconfigure:
	@mkdir -p states
	@echo "🔧 Initializing Terraform into [states/]..."
	terraform init -reconfigure

init_upgrade:
	@mkdir -p states
	@echo "🔧 Initializing Terraform into [states/]..."
	terraform init -upgrade

workspace:
	@echo "🔀 Using environment: [$(ENV)]..."
	@terraform workspace select $(ENV) 2>/dev/null || terraform workspace new $(ENV)

# Encrypt: secrets.tfvars -> secrets.json (intermediate) -> secrets.enc.json
encrypt:
	@jq -Rn '[inputs | select(length > 0) | capture("^\\s*(?<key>\\S+)\\s*=\\s*\"(?<value>.*)\"$$")] | from_entries' $(SECRETS_FILE) > $(SECRETS_JSON)
	@sops --encrypt $(SECRETS_JSON) > $(SECRETS_ENC)
	@rm -f $(SECRETS_JSON)
	@echo "🔒 Secrets encrypted to $(SECRETS_ENC)"

# Decrypt: secrets.enc.json -> secrets.json (intermediate) -> secrets.tfvars
decrypt:
	@sops --decrypt $(SECRETS_ENC) > $(SECRETS_JSON)
	@jq -r 'to_entries[] | "\(.key) = \"\(.value)\""' $(SECRETS_JSON) > $(SECRETS_FILE)
	@rm -f $(SECRETS_JSON)
	@echo "🔓 Secrets decrypted to $(SECRETS_FILE)"

plan: workspace decrypt
	@echo "📋 Planning infrastructure for [$(ENV)]..."
	terraform plan $(TF_VAR_ARGS)

apply: workspace decrypt
	@echo "🚀 Applying changes to [$(ENV)]..."
	terraform apply $(TF_VAR_ARGS)

refresh: workspace decrypt
	@echo "🔄 Refreshing state for [$(ENV)]..."
	terraform apply -refresh-only $(TF_VAR_ARGS)

destroy: workspace decrypt
	@echo "🔥 DESTROYING $(ENV) Infrastructure..."
	terraform destroy $(TF_VAR_ARGS)

fmt:
	@echo "🧹 Formatting code..."
	terraform fmt -recursive

validate:
	@echo "✅ Validating configuration..."
	terraform init -backend=false # Validate needs providers present
	terraform validate

output: workspace
	terraform output

kubeconfig: workspace
	@mkdir -p files/kubeconfigs
	@terraform output -raw talos_kubeconfigs | jq -r '.["$(CLUSTER)"]' > files/kubeconfigs/$(CLUSTER).yaml
	@echo "Kubeconfig → files/kubeconfigs/$(CLUSTER).yaml"

talosconfig: workspace
	@mkdir -p files/secrets
	@terraform output -raw talos_talosconfigs | jq -r '.["$(CLUSTER)"]' > files/secrets/$(CLUSTER)_talosconfig.yaml
	@echo "Talosconfig → files/secrets/$(CLUSTER)_talosconfig.yaml"
