# Fixes Applied to Proxmox Terraform Configuration

## Issues Fixed

### 1. **VM ID Collisions**
- Added `k3s_server_vm_id_base = 200` (servers get IDs 200-202)
- Added `k3s_agent_vm_id_base = 300` (agents get IDs 300-303)
- Each VM now gets a unique ID

### 2. **Cannot Login to VMs (SSH or Console)**
- **Root Cause:** Duplicate user/network configuration between `cloud-init.tpl.yaml` and Proxmox `initialization` block
- **Fix:** Removed users and network blocks from `cloud-init.tpl.yaml`
- **Fix:** Let Proxmox `initialization.user_account` and `initialization.ip_config` handle it exclusively
- **Fix:** Added `vm_password` variable for console access

### 3. **Network Configuration Conflict**
- Removed custom netplan config from cloud-init template
- Proxmox now handles all networking via `ip_config` block
- This prevents cloud-init/Proxmox conflicts

### 4. **SSH Key Rejected (Client-Side Private Key Permissions)**
- **Root Cause:** Client private key file permissions were too open (`0644`), so OpenSSH ignored the key.
- **Evidence:** SSH verbose log showed `WARNING: UNPROTECTED PRIVATE KEY FILE` and `Load key ... bad permissions`.
- **Fix:** Restrict permissions on the client key: `chmod 600 ~/.ssh/id_ed25519_k3st`.
- **Result:** Key-based authentication succeeds once permissions are corrected.

## What Changed

### `cloud-init.tpl.yaml`
- Removed `users:` block (now handled by Proxmox)
- Removed `network:` block (now handled by Proxmox)
- Kept only: hostname, package installation, qemu-guest-agent enable

### `main.tf`
- Added `vm_id` to both server and agent resources
- Added `password` parameter to `user_account` blocks

### `variables.tf`
- Added `k3s_server_vm_id_base`
- Added `k3s_agent_vm_id_base`
- Added `vm_password` (optional, for console access)

### `locals.tf`
- Added `server_vm_ids` map
- Added `agent_vm_ids` map

### `proxmox.auto.tfvars`
- Added `vm_password = "YOUR_PASSWORD_HERE"` (you must set this!)

## Next Steps

1. **Set your VM password** in `proxmox.auto.tfvars`:
   ```hcl
   vm_password = "your_secure_password"
   ```

2. **Destroy existing VMs**:
   ```bash
   terraform destroy -target=proxmox_virtual_environment_vm.k3s_server
   terraform destroy -target=proxmox_virtual_environment_vm.k3s_agent
   ```

3. **Recreate VMs with fixed config**:
   ```bash
   terraform apply -parallelism=2
   ```

4. **Test SSH access**:
   ```bash
   ssh chipfox@10.0.0.230
   ```

5. **Test console access** (from Proxmox):
   - Login: chipfox
   - Password: (what you set in vm_password)

6. **If SSH key is ignored on the client**:
   - Fix key permissions: `chmod 600 ~/.ssh/id_ed25519_k3st`
   - Retry SSH: `ssh -i ~/.ssh/id_ed25519_k3st chipfox@10.0.0.230`

## Why This Works

- **Single source of truth**: Proxmox `initialization` block handles user creation and networking
- **No conflicts**: Cloud-init only installs packages and enables services
- **Password set**: VM user now has both SSH key AND password for console access
- **Unique IDs**: No more VM ID collisions between servers and agents
