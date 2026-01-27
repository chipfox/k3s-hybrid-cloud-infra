# AWS: EKS cluster + node group

This Terraform root creates:

- A basic VPC (3 AZs if available)
- An EKS cluster
- An EKS managed node group (worker nodes)
- An AWS Secrets Manager secret (example of handling a secured secret)

## Prereqs

- Terraform >= 1.6
- AWS credentials configured (recommended: SSO / IAM Identity Center, or env vars)
  - Terraform uses the standard AWS credential chain

## Secure secret handling

This configuration intentionally does **not** hardcode any secrets.

Set the secret at apply-time using an environment variable:

- PowerShell: `setx TF_VAR_bootstrap_secret_value "..."`
- Or for the current session only: `$env:TF_VAR_bootstrap_secret_value = "..."`

Avoid committing secrets in any `*.tfvars` file (repo `.gitignore` already blocks those).

## Run

From this folder:

- `terraform init`
- `terraform plan`
- `terraform apply`

## Notes

- The VPC/subnet layout is intentionally simple. Adjust CIDRs, NAT gateways, and endpoint access to your standards.
- After apply, configure kubectl using the AWS CLI:
  - `aws eks update-kubeconfig --region <region> --name <cluster_name>`
