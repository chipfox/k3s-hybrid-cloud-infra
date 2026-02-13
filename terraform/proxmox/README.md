# Proxmox k3s Infrastructure

Creates Ubuntu Server VMs on Proxmox VE for k3s deployment:

- **Servers** (control-plane): `k3st-1`, `k3st-2`, `k3st-3` (VM IDs 200-202)
- **Agents** (workers): `k3st-a1`, `k3st-a2`, `k3st-a3`, ... (VM IDs 300+)

VMs are distributed across cluster nodes using round-robin placement.

## Prerequisites

- Terraform >= 1.6
- Proxmox VE cluster accessible from your workstation
- Ubuntu Server 25.10 cloud-init template VM with **qemu-guest-agent pre-installed**
- Datastore with **Snippets** content type enabled

### Template VM Requirements

Your template VM (referenced by `template_vm_id`) must have:
- `qemu-guest-agent` installed and enabled
- Clean state (no machine-id, SSH host keys cleared)
- Network configured for DHCP or no network config (cloud-init will configure)

To prepare a template:
```bash
# Inside the template VM before converting to template
sudo apt-get install -y qemu-guest-agent cloud-init
sudo systemctl enable qemu-guest-agent
sudo cloud-init clean --logs --seed
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo shutdown now
# Then convert to template in Proxmox
```

## Configuration

1. Copy `example.tfvars.example` to `proxmox.auto.tfvars`
2. Fill in your values (credentials, node names, storage IDs)
3. Generate SSH keys: `ssh-keygen -t ed25519 -f keys/id_ed25519`
4. Set `vm_password` in `.tfvars` for console access (optional)

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
set -a; source ../../.env; set +a
terraform plan
terraform apply
```

### SSH key configuration

Provide the **path** to your SSH public key file in `.tfvars`:

```hcl
vm_ssh_public_key = "keys/id_ed25519.pub"
vm_password = "your_secure_password"  # Optional: for console access
```

Terraform reads the file content automatically via `locals.tf`. Note: `.tfvars` files only support literal values, not function calls.

### Root Access

**Root login is disabled** by default. Only the user specified in `vm_user` (e.g., "chipfox" or "ubuntu") can login via SSH or console. This user has passwordless sudo access.

## Notes

- Template VM must have `qemu-guest-agent` pre-installed for IP reporting
- VMs use static IPs configured via Proxmox cloud-init integration
- User account is created with SSH key access (and optional password for console)
- Set `vm_datastore_id` to a datastore available on all nodes if storage differs per node
