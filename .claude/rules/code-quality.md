---
globs: "**/*.{tf,tftpl}"
---

# Code Quality Rules (Terraform/HCL)

- Each module has a single responsibility (one VM type or one infra concern).
- No resource block exceeds 50 lines. Extract into sub-modules if needed.
- No file exceeds 300 lines. Split into logical files (main.tf, variables.tf, outputs.tf).
- All variables have description and type constraints.
- All outputs have description fields.
- No hardcoded values in resource blocks. Use variables or locals.
- Use `for_each` over `count` when keys are meaningful (named VMs vs indexed replicas).
- Prefer early validation with `validation` blocks on variables.
- Group related resources with comments. Separate logical sections with blank lines.
- Sensitive values (tokens, passwords) marked with `sensitive = true`.
