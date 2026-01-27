# Ansible k3s Deployment

Deploys k3s cluster on Proxmox VMs created by Terraform.

## Prerequisites

1. Install Ansible:

   ```bash
   pip install ansible
   ```

2. VMs created and running via Terraform
3. SSH access configured (key: `../terraform/proxmox/keys/id_ed25519`)

## Configuration

### 1. Update Inventory

Edit `inventory.ini` with actual IP addresses from your VMs. You can get them from:

- Proxmox Web UI
- `terraform output` (if you add IP outputs to Terraform)
- DHCP server/router

### 2. Set k3s Token (Optional)

Generate a secure token:

```bash
export K3S_TOKEN=$(openssl rand -hex 32)
```

Or let Ansible generate one automatically (less secure for production).

## Deploy k3s

```bash
# Test connectivity
ansible -i inventory.ini all -m ping

# Deploy k3s cluster
ansible-playbook -i inventory.ini deploy-k3s.yaml

# Or with parallelism
ansible-playbook -i inventory.ini deploy-k3s.yaml --forks 1
```

## Post-Deployment

### Access the cluster

The kubeconfig file is automatically fetched to `./kubeconfig`:

```bash
export KUBECONFIG=$(pwd)/kubeconfig

# View nodes
kubectl get nodes -o wide

# View pods
kubectl get pods -A
```

### Update kubeconfig server address

If needed, update the server IP in kubeconfig:

```bash
kubectl config set-cluster default --server=https://<MASTER_IP>:6443
```

## Cluster Management

### Check cluster status

```bash
ansible -i inventory.ini k3s_masters[0] -m shell -a "kubectl get nodes" -b
```

### Restart k3s

```bash
# Masters
ansible -i inventory.ini k3s_masters -m systemd -a "name=k3s state=restarted" -b

# Agents
ansible -i inventory.ini k3s_agents -m systemd -a "name=k3s-agent state=restarted" -b
```

### Upgrade k3s

1. Update `k3s_version` in `deploy-k3s.yaml`
2. Re-run the playbook:

   ```bash
   ansible-playbook -i inventory.ini deploy-k3s.yaml
   ```

## Troubleshooting

### Check k3s logs

```bash
# On master nodes
ansible -i inventory.ini k3s_masters[0] -m shell -a "journalctl -u k3s -n 50" -b

# On agent nodes
ansible -i inventory.ini k3s_agents[0] -m shell -a "journalctl -u k3s-agent -n 50" -b
```

### Verify connectivity

```bash
# Test from agents to first master
ansible -i inventory.ini k3s_agents -m shell -a "nc -zv <MASTER_IP> 6443"
```

## Architecture

- **Masters** (k3st-1, k3st-2, k3st-3): Control plane with embedded etcd
- **Agents** (k3st-a1 - k3st-a5): Worker nodes
- **HA**: 3-node control plane for high availability
- **Datastore**: Embedded etcd (no external database needed)

## Notes

- First master (k3st-1) initializes the cluster with `--cluster-init`
- Additional masters join using the first master's address
- Agents join using any master's address (load balanced automatically)
- k3s uses port 6443 for API server
- All nodes need to communicate on this port
