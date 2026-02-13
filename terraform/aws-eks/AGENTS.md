# terraform/aws-eks — AGENTS.md

## OVERVIEW

AWS Terraform root for VPC + EKS managed node group + ArgoCD — the cloud leg of the one-button deployment pipeline.

### Role in the Pipeline

`terraform apply` in this directory does everything needed for a production EKS cluster:

1. **Creates VPC** — 3-AZ subnet layout with a single NAT gateway.
2. **Creates EKS cluster** — Managed node group with configurable instance types and scaling.
3. **Sets up IRSA** — IAM roles for ArgoCD controller and repo-server, enabling Secrets Manager access and cross-account assume-role without static credentials.
4. **Deploys ArgoCD** — Helm chart with IRSA-backed service accounts, ALB ingress, ACM certificate, and admin password from AWS Secrets Manager.

Once applied, ArgoCD syncs the same `gitops/` bootstrap chain used by the Proxmox/k3s cluster. ApplicationSets deploy workloads to any cluster labeled `environment: production`. No manual steps between `terraform apply` and running application pods.

## STRUCTURE

```
terraform/aws-eks/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
└── versions.tf
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| VPC/EKS modules | main.tf | terraform-aws-modules/vpc + eks |
| Inputs/defaults | variables.tf | Region, CIDR, cluster name, sizes |
| Outputs | outputs.tf | Cluster endpoint, secret ARN |
| Providers/versions | providers.tf, versions.tf | AWS provider + TF version |

## CODE STYLE

- **Self-documenting**: Module calls, variable names, and resource names must be immediately clear. No external docs needed to understand `main.tf` or `argocd.tf`.
- **Minimal**: Use community modules (`terraform-aws-modules/vpc`, `terraform-aws-modules/eks`) instead of raw resources where they reduce complexity. No wrapper modules around wrappers.
- **Secrets**: Admin password from AWS Secrets Manager (never in code). IRSA for ArgoCD pod access — no static IAM keys. Bootstrap secret via `TF_VAR_` env var (never committed).

## CONVENTIONS

- Secrets are provided via `TF_VAR_bootstrap_secret_value` env var.
- Project name prefixes resource names (VPC, node group).
- 3-AZ subnet layout with single NAT gateway.

## ANTI-PATTERNS

- Do not commit secrets in `*.tfvars`.
- Do not hardcode bootstrap secret values.

## COMMANDS

```bash
terraform init
terraform plan
terraform apply
```

## NOTES

- After apply, configure kubeconfig with `aws eks update-kubeconfig`.
