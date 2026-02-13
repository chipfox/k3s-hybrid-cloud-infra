# Deployment Guide - k3s Hybrid Cloud Infrastructure

**Last Updated:** 2026-02-13  
**Status:** Production Ready  
**Deployment Method:** Terraform (Infrastructure) + GitOps Bridge (ArgoCD)

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Architecture Overview](#architecture-overview)
4. [Proxmox k3s Deployment](#proxmox-k3s-deployment)
5. [AWS EKS Deployment](#aws-eks-deployment)
6. [GitOps Bridge Workflow](#gitops-bridge-workflow)
7. [Application Deployment with ArgoCD](#application-deployment-with-argocd)
8. [Verification and Testing](#verification-and-testing)
9. [Troubleshooting](#troubleshooting)
10. [Day-2 Operations](#day-2-operations)

---

## Quick Start

### For Proxmox k3s Cluster

```bash
# 1. Configure Terraform
cd terraform/proxmox
cp example.tfvars.example proxmox.auto.tfvars
# Edit proxmox.auto.tfvars with your settings

# 2. Generate SSH keys
ssh-keygen -t ed25519 -f keys/id_ed25519 -N "" -C "k3s-proxmox"

# 3. Deploy VMs
terraform init
export TF_CLI_ARGS_apply="-parallelism=1"
export TF_CLI_ARGS_plan="-parallelism=1"
terraform plan
terraform apply -auto-approve

# 4. Install k3s
cd ../../k3s-ansible
# Copy files to WSL (Windows only)
wsl bash -c "mkdir -p ~/k3s-ansible && cp -r /mnt/e/dev/k3s-hybrid-cloud-infra/k3s-ansible/* ~/k3s-ansible/"
wsl bash -c "cd ~/k3s-ansible && ansible-playbook playbook.yaml"

# 5. Deploy ArgoCD via GitOps Bridge
cd ../terraform/gitops-bridge
terraform init
terraform apply
```

### For AWS EKS Cluster

```bash
# 1. Configure Terraform
cd terraform/aws-eks
cp example.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# 2. Deploy EKS cluster
terraform init
terraform plan
terraform apply -auto-approve

# 3. Deploy ArgoCD via GitOps Bridge
cd ../gitops-bridge
terraform init
terraform workspace select eks || terraform workspace new eks
terraform apply
```

---

## Prerequisites

### Control Machine

**Windows with WSL Ubuntu:**
- Terraform >= 1.6
- Ansible: `sudo apt install ansible` (WSL)
- Python bcrypt: `pip3 install bcrypt`
- Git with submodule support
- kubectl
- Helm (for Terraform Helm provider)

**Linux/macOS:**
- Terraform >= 1.6
- Ansible >= 2.10
- Python bcrypt library
- kubectl
- Helm

### Proxmox Environment

- Proxmox VE cluster (tested with 4 nodes: pve-antec, sm2, supermicro, pve)
- Ubuntu 25.10 cloud-init template VM (ID 130) with qemu-guest-agent
- Shared storage "cluster-data" with Snippets content type enabled
- Network: 10.0.0.0/23 available (or customize in variables)

### AWS Environment

- AWS Account with sufficient permissions (VPC, EKS, IAM, EC2)
- AWS CLI configured with credentials
- Network access to AWS API endpoints

---

## Architecture Overview

### Deployment Architecture

This project uses a **GitOps Bridge pattern** for unified infrastructure and application management:

```
┌─────────────────────────────────────────────────────────────┐
│                    TERRAFORM (Day 0)                         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐                       │
│  │ Proxmox/k3s  │    │ AWS EKS      │                       │
│  │ VMs          │    │ Cluster      │                       │
│  └──────┬───────┘    └──────┬───────┘                       │
│         │                   │                               │
│         ▼                   ▼                               │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │ Helm Provider│    │ Helm Provider│                       │
│  │ ArgoCD       │    │ ArgoCD       │                       │
│  │ Bootstrap    │    │ Bootstrap    │                       │
│  └──────┬───────┘    └──────┬───────┘                       │
└─────────┼───────────────────┼───────────────────────────────┘
          │                   │
          ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                    GITOPS (Day 1+)                           │
├─────────────────────────────────────────────────────────────┤
│  ArgoCD ApplicationSets → Deploy apps to BOTH clusters      │
│                                                              │
│  ┌────────────────┐          ┌────────────────┐              │
│  │ Addons         │          │ Workloads      │              │
│  │ (ingress,      │          │ (guestbook,    │              │
│  │  monitoring)   │          │  custom apps)  │              │
│  └───────┬────────┘          └───────┬────────┘              │
│          │                          │                       │
│          └──────────┬───────────────┘                       │
│                     │                                       │
│                     ▼                                       │
│          ┌──────────────────┐                              │
│          │ Cluster Generator │                              │
│          │ (k3s + EKS)       │                              │
│          └──────────────────┘                              │
└─────────────────────────────────────────────────────────────┘
```

### Network Architecture (Proxmox k3s)

- **Cluster Network:** 10.0.0.0/23
- **Server IPs:** 10.0.0.230-232 (3 control-plane nodes)
- **Agent IPs:** 10.0.0.240-243 (4 worker nodes)
- **DNS & Gateway:** 10.0.0.1

### GitOps Repository Structure

```
gitops/
├── bootstrap/
│   └── argocd-bootstrap.yaml       # Initial ArgoCD configuration
├── addons/
│   └── addons-applicationset.yaml  # Cluster addons (ingress, monitoring)
├── workloads/
│   └── workloads-applicationset.yaml  # Application workloads
└── clusters/
    ├── k3s-proxmox.yaml            # k3s cluster registration
    └── eks-aws.yaml                # EKS cluster registration
```

---

## Proxmox k3s Deployment

### Step 1: Configure Terraform

#### 1.1 Copy and configure variables

```bash
cd terraform/proxmox
cp example.tfvars.example proxmox.auto.tfvars
```

Edit `proxmox.auto.tfvars`:
```hcl
proxmox_api_url          = "https://your-proxmox:8006/api2/json"
proxmox_api_token_id     = "terraform@pam!terraform"
proxmox_api_token_secret = "your-secret-token"
vm_user                  = "chipfox"
vm_password              = "your-secure-password"
# ... other settings
```

**IMPORTANT:** Never commit `*.auto.tfvars` files - they contain secrets.

#### 1.2 Generate SSH keys

```bash
cd terraform/proxmox
ssh-keygen -t ed25519 -f keys/id_ed25519 -N "" -C "k3s-proxmox"
```

#### 1.3 Copy SSH keys to WSL (Windows only)

```bash
wsl bash -c "mkdir -p ~/.ssh && cp /mnt/e/dev/k3s-hybrid-cloud-infra/terraform/proxmox/keys/id_ed25519* ~/.ssh/ && chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub"
```

### Step 2: Deploy VMs with Terraform

#### 2.1 Initialize Terraform

```bash
cd terraform/proxmox
terraform init
```

#### 2.2 Deploy VMs (with parallelism=1)

```bash
export TF_CLI_ARGS_apply="-parallelism=1"
export TF_CLI_ARGS_plan="-parallelism=1"
terraform plan
terraform apply -auto-approve
```

**CRITICAL:** `parallelism=1` is **required** to avoid Proxmox storage lock errors.

#### 2.3 Verify deployment

```bash
terraform output all_vm_ips
```

Expected: 7 VMs with IPs 10.0.0.230-232 (servers) and 10.0.0.240-243 (agents)

#### 2.4 Wait for cloud-init

Wait 60-90 seconds for cloud-init to complete on all VMs before proceeding.

### Step 3: Deploy k3s Cluster

#### 3.1 Copy Ansible files to WSL (Windows only)

```bash
wsl bash -c "mkdir -p ~/k3s-ansible && cp -r /mnt/e/dev/k3s-hybrid-cloud-infra/k3s-ansible/* ~/k3s-ansible/"
```

#### 3.2 Test connectivity

```bash
wsl bash -c "cd ~/k3s-ansible && ansible all -i inventory.ini -m ping"
```

All 7 nodes should respond with "pong".

#### 3.3 Run k3s-ansible playbook

```bash
wsl bash -c "cd ~/k3s-ansible && ansible-playbook playbook.yaml"
```

This takes ~5-10 minutes. It will:
- Install dependencies on all nodes
- Configure network settings
- Download and install k3s binaries
- Start k3s servers with embedded etcd
- Join agent nodes to cluster

#### 3.4 Verify cluster

```bash
wsl bash -c "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 chipfox@10.0.0.230 'sudo kubectl get nodes'"
```

Expected: All 7 nodes in "Ready" state.

### Step 4: Deploy ArgoCD via GitOps Bridge

**NOTE:** This step replaces the old Ansible-based ArgoCD deployment. Do not use `k3s-ansible/argocd.yaml` (deprecated).

#### 4.1 Configure GitOps Bridge

```bash
cd terraform/gitops-bridge
cp example.tfvars.example proxmox.auto.tfvars
```

Edit `proxmox.auto.tfvars`:
```hcl
cluster_name = "k3s-proxmox"
kubeconfig_path = "../../k3s-ansible/kubeconfig"
argocd_admin_password = "your-secure-password"  # Plain text - will be bcrypt hashed
gitops_repo_url = "https://github.com/chipfox/k3s-hybrid-cloud-infra.git"
gitops_repo_path = "gitops"
```

#### 4.2 Deploy ArgoCD

```bash
cd terraform/gitops-bridge
terraform init
terraform apply
```

Terraform will:
- Install ArgoCD v2.13.2 via Helm
- Configure admin password (bcrypt hashed)
- Bootstrap GitOps applications from `gitops/` directory
- Deploy ApplicationSets for addons and workloads

#### 4.3 Verify ArgoCD

```bash
# Check ArgoCD pods
kubectl --kubeconfig ../../k3s-ansible/kubeconfig get pods -n argocd

# Check ArgoCD applications
kubectl --kubeconfig ../../k3s-ansible/kubeconfig get applications -n argocd
```

Expected: 7 ArgoCD pods running, applications showing "Synced" and "Healthy"

### Step 5: Access ArgoCD

#### Access Methods

**Option 1: NodePort (Recommended for on-prem)**

ArgoCD is exposed on all server nodes via NodePort:

```
https://10.0.0.230:30080
https://10.0.0.231:30080
https://10.0.0.232:30080
```

**Option 2: Port forward**

```bash
kubectl --kubeconfig k3s-ansible/kubeconfig port-forward svc/argocd-server -n argocd 8080:443
```

Visit: https://localhost:8080

**Login:**
- Username: `admin`
- Password: Value from `argocd_admin_password` in `proxmox.auto.tfvars`

---

## AWS EKS Deployment

### Step 1: Configure Terraform

```bash
cd terraform/aws-eks
cp example.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
cluster_name = "hybrid-eks"
cluster_version = "1.28"
vpc_cidr = "10.1.0.0/16"
# ... other EKS settings
```

### Step 2: Deploy EKS Cluster

```bash
cd terraform/aws-eks
terraform init
terraform plan
terraform apply -auto-approve
```

This creates:
- VPC with 3 availability zones
- EKS control plane
- Managed node group
- IRSA roles for ArgoCD

### Step 3: Update kubeconfig

```bash
aws eks update-kubeconfig --region <region> --name hybrid-eks
```

### Step 4: Deploy ArgoCD via GitOps Bridge

```bash
cd terraform/gitops-bridge
terraform init
terraform workspace select eks || terraform workspace new eks
terraform apply
```

### Step 5: Verify EKS Deployment

```bash
# Check nodes
kubectl get nodes

# Check ArgoCD
kubectl get pods -n argocd
kubectl get applications -n argocd
```

---

## GitOps Bridge Workflow

### Overview

The GitOps Bridge pattern eliminates the need for manual ArgoCD configuration. Terraform manages the complete lifecycle:

**Day 0 (Infrastructure):**
1. Terraform provisions infrastructure (VMs or EKS cluster)
2. Terraform installs ArgoCD via Helm provider
3. Terraform bootstraps GitOps Applications

**Day 1+ (Applications):**
1. All application changes made in Git repository
2. ArgoCD automatically syncs changes to cluster
3. Self-healing if manual changes are made

### Key Benefits

- **Unified Workflow:** Single `terraform apply` for infrastructure + ArgoCD
- **Multi-Cluster Support:** Deploy to both k3s and EKS from single GitOps repo
- **No Ansible for ArgoCD:** Ansible only used for initial k3s installation
- **GitOps-native:** All application state tracked in Git
- **Self-Healing:** ArgoCD automatically corrects configuration drift

### Workflow Comparison

**Old Workflow (Ansible):**
```bash
terraform apply          # Provision VMs
ansible-playbook site.yml     # Install k3s
ansible-playbook argocd.yaml  # Install ArgoCD
ansible-playbook argocd-app.yaml  # Configure apps
```

**New Workflow (GitOps Bridge):**
```bash
terraform apply          # Provision VMs
ansible-playbook site.yml     # Install k3s
cd ../terraform/gitops-bridge
terraform apply          # Install ArgoCD + bootstrap apps
```

---

## Application Deployment with ArgoCD

### Using ApplicationSets

ApplicationSets allow you to deploy applications across multiple clusters with a single manifest.

**Example: Deploy guestbook to all production clusters**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
  template:
    metadata:
      name: '{{name}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/chipfox/argo-apps.git
        targetRevision: HEAD
        path: apps/guestbook
      destination:
        server: '{{server}}'
        namespace: guestbook
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

### Adding New Applications

1. **Create application manifests** in `argo-apps/apps/<app-name>/`
2. **Define ArgoCD Application** in `gitops/workloads/` or `gitops/addons/`
3. **Commit and push** to Git repository
4. **ArgoCD auto-syncs** within 3 minutes (or trigger manually)

### Directory Structure

```
argo-apps/
└── apps/
    ├── guestbook/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── kustomization.yaml
    └── immich/
        ├── deployment.yaml
        ├── service.yaml
        └── configmap.yaml
```

---

## Verification and Testing

### Cluster Health Checks

```bash
# Check all nodes are Ready
kubectl get nodes

# Check all system pods running
kubectl get pods -A

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

### ArgoCD Health Checks

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD applications
kubectl get applications -n argocd

# Detailed application status
kubectl describe application <app-name> -n argocd
```

### Application Health Checks

```bash
# Check application pods
kubectl get pods -n <namespace>

# Check application logs
kubectl logs -n <namespace> <pod-name>

# Check service endpoints
kubectl get svc -n <namespace>
```

### Verification Checklist

- [ ] All VMs/nodes created with correct IPs
- [ ] SSH key authentication working
- [ ] All nodes showing "Ready" status
- [ ] k3s cluster with HA control plane (if Proxmox)
- [ ] ArgoCD installed and accessible
- [ ] ArgoCD applications synced and healthy
- [ ] Can access ArgoCD web UI
- [ ] Can deploy test application successfully

---

## Troubleshooting

### Infrastructure Issues

#### Terraform storage lock errors (Proxmox)

**Problem:** Multiple VMs being created in parallel causes Proxmox storage locks.

**Solution:** Always use `parallelism=1`:
```bash
export TF_CLI_ARGS_apply="-parallelism=1"
terraform apply
```

#### SSH key permission denied

**Problem:** SSH keys on Windows filesystem (`/mnt/e/...`) have 0777 permissions in WSL.

**Solution:** Copy keys to WSL home directory:
```bash
wsl bash -c "cp /mnt/e/.../keys/id_ed25519 ~/.ssh/ && chmod 600 ~/.ssh/id_ed25519"
```

#### Known_hosts warnings after VM recreation

**Problem:** VMs get new host keys when recreated, causing SSH warnings.

**Solution:** Use `-o UserKnownHostsFile=/dev/null` in SSH commands:
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 user@host
```

Or clear known_hosts:
```bash
rm -f ~/.ssh/known_hosts  # WSL
del C:\Users\Chipf\.ssh\known_hosts  # Windows
```

#### Ansible ignores ansible.cfg (Windows WSL)

**Problem:** Ansible refuses to read `ansible.cfg` from world-writable directory (`/mnt/e/...`).

**Solution:** Copy k3s-ansible directory to WSL home:
```bash
cp -r /mnt/e/dev/k3s-hybrid-cloud-infra/k3s-ansible ~/k3s-ansible
cd ~/k3s-ansible
ansible-playbook playbook.yaml
```

### ArgoCD Issues

#### Helm timeout during ArgoCD installation

**Problem:** Helm release times out waiting for pods.

**Solution:** Check pod logs for errors:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

Common causes:
- Image pull failures (check network/registry access)
- Resource limits too low (increase in Helm values)
- Node resource exhaustion (check `kubectl top nodes`)

#### ArgoCD application stuck in "Syncing"

**Problem:** Application never completes sync.

**Solution:** Check sync status:
```bash
kubectl describe application <app-name> -n argocd
```

Common causes:
- Git repository not accessible (check credentials)
- Invalid manifest syntax (check application logs)
- Resource conflicts (check for existing resources)

#### ArgoCD application "OutOfSync"

**Problem:** Application shows "OutOfSync" status.

**Solution:** 
1. Check what's different: ArgoCD UI → App Details → Diff
2. If expected: Sync manually or enable auto-sync
3. If unexpected: Someone made manual `kubectl` changes - revert or commit to Git

#### Cannot access ArgoCD UI

**Problem:** Cannot connect to ArgoCD web interface.

**Solution (Proxmox NodePort):**
```bash
# Verify NodePort service
kubectl get svc -n argocd argocd-server

# Test from control machine
curl -k https://10.0.0.230:30080/healthz

# Check firewall rules (Proxmox host)
```

**Solution (Port forward):**
```bash
# Forward in background
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access at https://localhost:8080
```

### Kubernetes Issues

#### Pods stuck in "Pending" state

**Problem:** Pods not scheduling.

**Solution:** Check why:
```bash
kubectl describe pod <pod-name> -n <namespace>
```

Common causes:
- Insufficient resources (CPU/memory)
- Node selector mismatch
- PersistentVolumeClaim not bound
- Image pull errors

#### kubectl permission denied

**Problem:** `kubectl` commands fail with permission errors.

**Solution (k3s):** Use sudo or copy kubeconfig:
```bash
# Option 1: Use sudo
sudo kubectl get nodes

# Option 2: Copy kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
```

### Terraform State Issues

#### Terraform state locked

**Problem:** Terraform operations blocked by state lock.

**Solution:** Ensure no other Terraform processes running, then:
```bash
# List locks
terraform force-unlock <lock-id>

# WARNING: Only if certain no other process is running
```

#### Helm release already exists

**Problem:** Terraform fails because Helm release exists from previous installation.

**Solution:** Import existing release:
```bash
terraform import helm_release.argocd argocd/argocd
```

Or delete and recreate:
```bash
helm uninstall argocd -n argocd
terraform apply
```

---

## Day-2 Operations

### Upgrading ArgoCD

Update the `chart_version` in your GitOps Bridge Terraform configuration:

```hcl
# terraform/gitops-bridge/main.tf
resource "helm_release" "argocd" {
  chart   = "argo-cd"
  version = "5.51.4"  # Update version here
  # ...
}
```

Apply changes:
```bash
cd terraform/gitops-bridge
terraform plan
terraform apply
```

### Upgrading Applications

Update the `targetRevision` in your ArgoCD Application manifest:

```yaml
spec:
  source:
    targetRevision: v2.0.0  # Update version/branch/tag
```

Commit to Git - ArgoCD will auto-sync if configured.

### Adding New Clusters

1. **Create cluster with Terraform** (Proxmox or EKS)
2. **Register cluster in GitOps Bridge**:
   ```bash
   cd terraform/gitops-bridge
   terraform workspace new <cluster-name>
   terraform apply
   ```
3. **Add cluster secret** to `gitops/clusters/<cluster-name>.yaml`
4. **Commit and push** - ArgoCD will discover the new cluster

### Backing Up ArgoCD

```bash
# Export all applications
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml

# Export projects
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml

# Export ArgoCD secrets
kubectl get secret -n argocd -o yaml > argocd-secrets-backup.yaml
```

### Disaster Recovery

**Proxmox k3s Cluster:**
1. VMs are recreated with Terraform
2. k3s reinstalled with Ansible
3. ArgoCD reinstalled with Terraform GitOps Bridge
4. Applications auto-sync from Git

**State files to back up:**
- `terraform.tfstate` (all Terraform roots)
- `*.auto.tfvars` (contains secrets)
- SSH keys in `keys/` directory

### Monitoring and Observability

**Recommended stack (deploy via ApplicationSet):**
- Prometheus for metrics
- Grafana for dashboards
- Loki for logs
- AlertManager for alerts

**ArgoCD built-in metrics:**
```bash
# Port forward Prometheus metrics
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082

# View metrics
curl http://localhost:8082/metrics
```

### Updating Infrastructure

**Proxmox VMs:**
```bash
cd terraform/proxmox
# Edit variables or main.tf
terraform plan
terraform apply
```

**AWS EKS:**
```bash
cd terraform/aws-eks
# Edit variables or main.tf
terraform plan
terraform apply
```

**Note:** Changes to node count, instance types, or VPC configuration require careful planning to avoid downtime.

---

## Current Deployment Status

**Proxmox k3s Cluster:**
- ✅ 7 VMs operational (3 servers + 4 agents)
- ✅ k3s v1.28.5+k3s1 with embedded etcd (HA)
- ✅ ArgoCD v2.13.2 deployed via GitOps Bridge
- ✅ Guestbook application deployed and healthy
- ✅ NodePort services exposed on 10.0.0.230-232

**AWS EKS Cluster:**
- ⏸️ Infrastructure ready (Terraform modules exist)
- ⏸️ Not yet deployed (follow AWS EKS Deployment section)

**GitOps Repository:**
- ✅ Bootstrap ApplicationSet configured
- ✅ Addons ApplicationSet configured
- ✅ Workloads ApplicationSet configured
- ✅ Cluster secrets registered (k3s-proxmox, eks-aws)

---

## Next Steps

### For New Deployments

1. Follow [Quick Start](#quick-start) for your target platform
2. Verify deployment with [Verification and Testing](#verification-and-testing)
3. Deploy sample applications to test GitOps workflow
4. Set up monitoring and observability
5. Configure ingress and external access

### For Existing Users

1. Review [Day-2 Operations](#day-2-operations) for maintenance procedures
2. Set up backup procedures for critical state
3. Plan application migration strategy (see HAPROXY-INTEGRATION.md)
4. Configure multi-cluster management if using both k3s and EKS

### For Production Use

1. ✅ Rotate default passwords (ArgoCD admin, VM user)
2. ✅ Configure proper TLS certificates (not self-signed)
3. ✅ Set up monitoring and alerting
4. ✅ Implement backup and disaster recovery procedures
5. ✅ Configure RBAC for team access
6. ✅ Set up CI/CD pipeline for application deployments

---

## References

- [k3s Documentation](https://docs.k3s.io/)
- [k3s-ansible Collection](https://github.com/k3s-io/k3s-ansible)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Bridge Terraform Module](https://registry.terraform.io/modules/gitops-bridge-dev/gitops-bridge/helm/latest)
- [Proxmox Terraform Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/)

---

**Generated:** 2026-02-13  
**Infrastructure Version:** k3s v1.28.5, ArgoCD v2.13.2  
**Deployment Method:** Terraform + GitOps Bridge  
**Status:** Production Ready
