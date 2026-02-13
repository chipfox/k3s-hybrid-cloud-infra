# Terraform Parallelism Configuration

## Problem
Proxmox shared storage (cluster-data) experiences lock contention when Terraform tries to create multiple VMs simultaneously, resulting in errors like:
```
cfs-lock 'storage-cluster-data' error: got lock request timeout
```

## Solution
Always run Terraform with `parallelism=1` to create VMs sequentially.

## Implementation

### Option 1: Environment Variables (Recommended)
Set these before running terraform:
```bash
export TF_CLI_ARGS_plan="-parallelism=1"
export TF_CLI_ARGS_apply="-parallelism=1"
terraform apply
```

### Option 2: Use Helper Script
```bash
./terraform-apply.sh apply -auto-approve
./terraform-apply.sh plan
./terraform-apply.sh destroy
```

### Option 3: Explicit Flag
```bash
terraform apply -parallelism=1 -auto-approve
terraform plan -parallelism=1
```

## Why Not terraform.rc in Project Directory?
Terraform does NOT read CLI configuration from project-level `terraform.rc` files. CLI configs must be in:
- `~/.terraformrc` (Unix/Linux/Mac)
- `%APPDATA%\terraform.rc` (Windows)
- Or set via `TF_CLI_CONFIG_FILE` environment variable

Environment variables (`TF_CLI_ARGS_*`) are the simplest project-specific solution.

## Created Files
- `.envrc` - For direnv users (auto-loads environment variables when entering directory)
- `terraform-apply.sh` - Wrapper script that sets env vars and runs terraform
- This README

## References
- Terraform CLI Configuration: https://developer.hashicorp.com/terraform/cli/config/config-file
- Environment Variables: https://developer.hashicorp.com/terraform/cli/config/environment-variables
