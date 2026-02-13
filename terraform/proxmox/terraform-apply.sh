#!/usr/bin/env bash
# Terraform apply wrapper with parallelism=1 for Proxmox storage lock prevention

export TF_CLI_ARGS_plan="-parallelism=1"
export TF_CLI_ARGS_apply="-parallelism=1"

terraform "$@"
