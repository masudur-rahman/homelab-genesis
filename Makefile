# 🛠️ Project Genesis Makefile

# 1. Find all .tfvars files recursively (in vars/dev, vars/prod, etc.)
# We use 'shell find' because standard Make wildcards don't do recursion well
VAR_FILES := $(shell find vars -name "*.tfvars")

# 2. Format them into flags
TF_FLAGS := $(foreach file,$(VAR_FILES),-var-file="$(file)")

.PHONY: all init plan apply refresh destroy fmt validate output console

all: plan

init:
	@echo "🚀 Initializing Terraform..."
	terraform init

plan:
	@echo "🔮 Planning infrastructure..."
	# Prints which var files are being loaded (for debugging)
	@echo "   Loading vars: $(VAR_FILES)"
	terraform plan $(TF_FLAGS)

apply:
	@echo "🏗️  Applying changes..."
	terraform apply $(TF_FLAGS)

refresh:
	@echo "🔄 Refreshing state..."
	terraform apply -refresh-only $(TF_FLAGS)

destroy:
	@echo "🔥 DESTROYING Infrastructure..."
	terraform destroy $(TF_FLAGS)

fmt:
	@echo "🧹 Formatting code..."
	terraform fmt -recursive

validate:
	@echo "✅ Validating configuration..."
	terraform validate

output:
	terraform output