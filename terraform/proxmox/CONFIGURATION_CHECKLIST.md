# Configuration Verification Checklist

## ✅ Current Configuration Status

### User Access Configuration
- **Primary User**: Configured via `vm_user` variable (e.g., "chipfox" or "ubuntu")
- **SSH Access**: ✅ Enabled via `vm_ssh_public_key`
- **Console Access**: ✅ Enabled via `vm_password` (optional)
- **Root Access**: ❌ Disabled (by design - use sudo instead)

### VM ID Assignment
- **Servers**: VM IDs starting at `k3s_server_vm_id_base` (default: 200)
  - k3st-1 → VM ID 200
  - k3st-2 → VM ID 201
  - k3st-3 → VM ID 202
- **Agents**: VM IDs starting at `k3s_agent_vm_id_base` (default: 300)
  - k3st-a1 → VM ID 300
  - k3st-a2 → VM ID 301
  - k3st-a3 → VM ID 302
  - etc.

### Network Configuration
- **Static IPs**: Configured via Proxmox `initialization.ip_config` block
- **Servers**: `k3s_server_ip_base` + index (default: 10.0.0.230+)
- **Agents**: `k3s_agent_ip_base` + index (default: 10.0.0.240+)
- **DNS/Gateway**: Configured via variables

### Cloud-Init Strategy
- **User/Network**: Handled by Proxmox `initialization` block (NOT cloud-init user-data)
- **Packages**: `qemu-guest-agent` installed via cloud-init
- **Services**: `qemu-guest-agent` enabled via cloud-init runcmd

## 📋 File Consistency Matrix

| File | Purpose | Status | Notes |
|------|---------|--------|-------|
| `main.tf` | VM resources | ✅ Updated | Uses `vm_id`, `vm_password`, `agent.enabled=true` |
| `variables.tf` | Variable definitions | ✅ Updated | Added `vm_password`, VM ID base variables |
| `locals.tf` | Computed values | ✅ Updated | Added `server_vm_ids`, `agent_vm_ids` maps |
| `cloud-init.tpl.yaml` | Cloud-init template | ✅ Updated | Removed users/network blocks |
| `outputs.tf` | Terraform outputs | ✅ Updated | Uses `${var.vm_user}` instead of hardcoded |
| `README.md` | Documentation | ✅ Updated | Reflects current config, root access note |
| `example.tfvars.example` | Example config | ✅ Updated | Added `vm_password`, VM ID base vars |
| `inventory.tpl` | Ansible template | ✅ Correct | Uses `${vm_user}` variable |

## 🔍 Configuration Values to Verify

### In `proxmox.auto.tfvars`:
```hcl
# ✅ These should match your environment
proxmox_endpoint     = "https://YOUR_IP:8006"
proxmox_nodes        = ["node1", "node2", ...]
template_vm_id       = 130  # Your template VMID
vm_user              = "chipfox"  # Or "ubuntu"
vm_ssh_public_key    = "keys/id_ed25519.pub"
vm_password          = "YourPassword"  # For console access

# ✅ VM ID ranges (prevent collisions)
k3s_server_vm_id_base = 200  # Optional, default is 200
k3s_agent_vm_id_base  = 300  # Optional, default is 300

# ✅ IP ranges (must not overlap)
k3s_server_ip_base   = "10.0.0.230"  # Servers: .230, .231, .232
k3s_agent_ip_base    = "10.0.0.240"  # Agents: .240, .241, .242...
```

### In Template VM (ID 130):
```bash
# ✅ Must be pre-installed
dpkg -l | grep qemu-guest-agent  # Should show installed
systemctl status qemu-guest-agent  # Should be enabled

# ✅ Should be clean
cat /etc/machine-id  # Should be empty or minimal
ls /etc/netplan/*.yaml  # Should have no static IPs configured
```

## 🚀 Deployment Verification

After `terraform apply`, verify:

### 1. SSH Access
```bash
ssh chipfox@10.0.0.230  # Should work with key
ssh chipfox@10.0.0.240  # Should work with key
ssh root@10.0.0.230     # Should FAIL (root login disabled)
```

### 2. Console Access (via Proxmox)
- Username: `chipfox` (or your `vm_user`)
- Password: (value from `vm_password` variable)
- Root: Should FAIL

### 3. Network Configuration
```bash
# From inside a VM
ip addr show ens18  # Should show static IP (10.0.0.230, etc.)
ping 8.8.8.8        # Should work
ping 10.0.0.1       # Should reach gateway
```

### 4. Sudo Access
```bash
# From inside a VM as chipfox
sudo whoami  # Should print "root" without password prompt
```

### 5. Terraform State
```bash
# Check reported IPs
terraform output all_vm_ips
# Should show actual IPs (10.0.0.230+), NOT 127.0.0.1
```

## ⚠️ Common Issues

### Issue: Cannot login with root
**Expected**: Root login is disabled by design
**Solution**: Login as `vm_user` (chipfox/ubuntu) and use `sudo` for root access

### Issue: VMs report 127.0.0.1 in terraform state
**Cause**: qemu-guest-agent not running or network not configured
**Solution**: 
1. Check template has agent pre-installed
2. Verify `agent.enabled = true` in main.tf
3. Check cloud-init logs: `sudo cat /var/log/cloud-init.log`

### Issue: SSH key authentication fails
**Cause**: Key mismatch or permissions issue
**Solution**:
1. Verify `keys/id_ed25519.pub` matches your client's public key
2. Check permissions: `chmod 600 ~/.ssh/id_ed25519`
3. Verify SSH config points to correct private key

### Issue: VM ID collisions
**Cause**: VM IDs overlap between servers and agents
**Solution**: Ensure `k3s_server_vm_id_base` and `k3s_agent_vm_id_base` are at least 100 apart

## 📝 Summary

**Your current configuration**:
- ✅ Root login: **Disabled** (by design)
- ✅ User login: **chipfox** (SSH + console)
- ✅ VM IDs: **Unique** (200+ for servers, 300+ for agents)
- ✅ Network: **Static IPs** via Proxmox initialization
- ✅ Agent: **Enabled** for IP reporting
- ✅ Documentation: **Updated** to match implementation

**All files are now consistent** with the working configuration where:
- You can login as `chipfox` via SSH and console
- Root login is disabled
- Each VM has a unique ID
- Static IPs are properly configured
