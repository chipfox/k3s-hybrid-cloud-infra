#!/usr/bin/env bash
# Terraform apply wrapper with parallelism=1 for Proxmox storage lock prevention

# Load root .env if present (git-ignored)
if [ -f "../../.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "../../.env"
  set +a
fi

terraform "$@"
