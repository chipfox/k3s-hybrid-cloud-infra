# Proxmox k3s Infrastructure

Creates Ubuntu Server VMs on Proxmox VE for k3s deployment:

- **Servers** (control-plane): `k3st-1`, `k3st-2`, `k3st-3`
- **Agents** (workers): `k3st-a1`, `k3st-a2`, `k3st-a3`, ...

VMs are distributed across cluster nodes using round-robin placement.

## Prerequisites

- Terraform >= 1.6
- Proxmox VE cluster accessible from your workstation
- Ubuntu Server 25.10 cloud-init template VM (provide VMID via `template_vm_id`)
- Datastore with **Snippets** content type enabled

## Configuration

1. Copy `example.tfvars.example` to `proxmox.auto.tfvars`
2. Fill in your values (credentials, node names, storage IDs)
3. Generate SSH keys: `ssh-keygen -t ed25519 -f keys/id_ed25519`

### Storage IDs

Use Proxmox **storage IDs**, not filesystem paths:

- ✅ `snippets_datastore_id = "cluster-data"`
- ❌ `/mnt/pve/cluster-data/` (mount path)

### Cloud-init snippets

- **Shared storage** (NFS/CephFS): Set `snippets_node_name` to any node
- **Local storage**: Snippets upload to each VM's target node automatically

## Usage

```bash
terraform init
terraform plan
terraform apply
```

### SSH key configuration

Provide the **path** to your SSH public key file in `.tfvars`:

```hcl
vm_ssh_public_key = "keys/id_ed25519.pub"
```

Terraform reads the file content automatically via `locals.tf`. Note: `.tfvars` files only support literal values, not function calls.

## Notes

- `qemu-guest-agent` is installed via cloud-init but `agent.enabled = false` to avoid first-boot timeouts
- Set `vm_datastore_id` to a datastore available on all nodes if storage differs per node
