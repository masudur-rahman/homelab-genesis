# 🛠️ Project Genesis Makefile
ENV ?= compute

export TF_DATA_DIR := states/.terraform

COMMON_VARS := vars/common.tfvars
ENV_VAR_FILES := $(wildcard vars/$(ENV)/*.tfvars)
TF_VAR_ARGS := -var-file="$(COMMON_VARS)" $(foreach file,$(ENV_VAR_FILES),-var-file="$(file)")

.PHONY: init plan apply destroy workspace fmt validate output init_reconfigure

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

plan: workspace
	@echo "📋 Planning infrastructure for [$(ENV)]..."
	terraform plan $(TF_VAR_ARGS)

apply: workspace
	@echo "🚀 Applying changes to [$(ENV)]..."
	terraform apply $(TF_VAR_ARGS)

refresh: workspace
	@echo "🔄 Refreshing state for [$(ENV)]..."
	terraform apply -refresh-only $(TF_VAR_ARGS)

destroy: workspace
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
