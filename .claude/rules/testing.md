---
globs: "**/*.{tf,tfvars}"
---

# Validation & Testing Rules (Terraform)

- Run `terraform validate` after any structural change.
- Run `terraform plan` to verify expected resource changes before apply.
- Use `make fmt` to ensure consistent formatting.
- Variable validation blocks for constraints (e.g., memory >= 512, cpu >= 1).
- Check `terraform plan` output for unexpected destroys/recreates.
- Verify cloud-init template rendering with `terraform console` when modifying templates.
