# GitOps Bridge (Argo CD)

This root installs Argo CD and bootstraps GitOps apps using the GitOps Bridge module.

## Workspaces

- `proxmox`
- `eks`

## Proxmox flow

1. Provision VMs:
   ```bash
   cd ../proxmox
   terraform init
   terraform apply
   ```
2. Bootstrap k3s:
   ```bash
   cd ../../k3s-ansible
   ansible-playbook playbook.yaml
   ```
3. Fetch kubeconfig to `k3s-ansible/kubeconfig`.
4. Create `terraform/gitops-bridge/proxmox.auto.tfvars` from the example.
   - Copy `argocd_admin_password` from `terraform/proxmox/proxmox.auto.tfvars`.
5. Deploy GitOps Bridge:
   ```bash
   cd ../terraform/gitops-bridge
   terraform init
   terraform workspace select proxmox || terraform workspace new proxmox
   terraform apply
   ```

## EKS flow (future)

1. Provision EKS:
   ```bash
   cd ../aws-eks
   terraform init
   terraform apply
   ```
2. Update kubeconfig:
   ```bash
   aws eks update-kubeconfig --name <cluster-name> --region <region>
   ```
3. Create `terraform/gitops-bridge/eks.auto.tfvars` from the example.
4. Deploy GitOps Bridge using the `eks` workspace.

## Notes

- `argocd-values.yaml` configures NodePort 30080/30443 and repo URL.
- GitOps manifests live under `gitops/` (bootstrap/addons/workloads).
