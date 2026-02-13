# ArgoCD Cluster Configuration Examples

This document contains configuration examples for advanced ArgoCD cluster registration scenarios. These examples were extracted from the cluster secret manifests in `gitops/clusters/`.

---

## Overview

ArgoCD cluster secrets allow you to register external Kubernetes clusters for multi-cluster management. The basic cluster registration uses a simple server URL, but advanced scenarios require additional configuration for authentication and TLS.

---

## Basic Cluster Registration

**File:** `gitops/clusters/k3s-proxmox.yaml` or `gitops/clusters/eks-aws.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: k3s-proxmox-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: k3s-proxmox
  server: https://kubernetes.default.svc
  config: "{}"
```

**Key Fields:**
- `name`: Human-readable cluster name (shows in ArgoCD UI)
- `server`: Kubernetes API server URL
- `config`: JSON configuration (empty `{}` for in-cluster or simple external clusters)

---

## Advanced Configuration Examples

### 1. TLS Client Certificate Authentication (k3s Proxmox)

**Use case:** Connecting to a k3s cluster using mutual TLS authentication with client certificates.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: k3s-proxmox-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: k3s-proxmox
  server: https://10.0.0.230:6443
  config: |
    {
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64-encoded-ca-cert>",
        "certData": "<base64-encoded-client-cert>",
        "keyData": "<base64-encoded-client-key>"
      }
    }
```

**Configuration Fields:**
- `tlsClientConfig.insecure`: Set to `false` to verify server certificate (recommended)
- `tlsClientConfig.caData`: Base64-encoded CA certificate (validates server identity)
- `tlsClientConfig.certData`: Base64-encoded client certificate (authenticates ArgoCD to cluster)
- `tlsClientConfig.keyData`: Base64-encoded client private key (paired with certData)

**How to obtain values:**

```bash
# Extract from k3s kubeconfig
KUBECONFIG=k3s-ansible/kubeconfig

# CA certificate
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'

# Client certificate
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}'

# Client key
kubectl config view --raw -o jsonpath='{.users[0].user.client-key-data}'
```

---

### 2. AWS EKS with IAM Authentication

**Use case:** Connecting ArgoCD to an AWS EKS cluster using IAM roles for service accounts (IRSA).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: eks-aws-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: eks-aws
  server: https://ABCDEF1234567890.gr7.us-east-1.eks.amazonaws.com
  config: |
    {
      "awsAuthConfig": {
        "clusterName": "hybrid-eks",
        "roleARN": "arn:aws:iam::123456789012:role/argocd-controller-role"
      },
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64-encoded-ca-cert>"
      }
    }
```

**Configuration Fields:**
- `awsAuthConfig.clusterName`: Name of the EKS cluster
- `awsAuthConfig.roleARN`: IAM role ARN that ArgoCD assumes to access the cluster
- `tlsClientConfig.caData`: Base64-encoded EKS cluster CA certificate

**How to obtain values:**

```bash
# Get EKS cluster endpoint
aws eks describe-cluster --name hybrid-eks --query 'cluster.endpoint' --output text

# Get CA certificate
aws eks describe-cluster --name hybrid-eks --query 'cluster.certificateAuthority.data' --output text

# IAM role ARN (created by Terraform in aws-eks/argocd.tf)
terraform output -raw argocd_irsa_role_arn
```

**Prerequisites:**
- IRSA configured for ArgoCD (Terraform module: `terraform/aws-eks/argocd.tf`)
- ArgoCD service account annotated with IAM role ARN
- EKS cluster configured to trust the IAM role

---

### 3. Bearer Token Authentication

**Use case:** Connecting to a cluster using a service account token (common for generic Kubernetes clusters).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: external-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: external-k8s
  server: https://external-cluster.example.com:6443
  config: |
    {
      "bearerToken": "<service-account-token>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64-encoded-ca-cert>"
      }
    }
```

**How to create service account and extract token:**

```bash
# On target cluster
kubectl create serviceaccount argocd-manager -n kube-system

kubectl create clusterrolebinding argocd-manager \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:argocd-manager

# Get token (Kubernetes 1.24+)
kubectl create token argocd-manager -n kube-system --duration=87600h

# Get CA certificate
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
```

---

### 4. Insecure Connection (Development Only)

**⚠️ WARNING:** Only use for development/testing. **Never use in production.**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dev-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: dev-cluster
  server: https://dev-cluster.local:6443
  config: |
    {
      "tlsClientConfig": {
        "insecure": true
      }
    }
```

**Use case:** Local development clusters with self-signed certificates where certificate validation is impractical.

---

## Configuration Field Reference

### Complete Config Schema

```json
{
  "bearerToken": "string (optional)",
  "tlsClientConfig": {
    "insecure": false,
    "caData": "base64-encoded-ca-cert (optional)",
    "certData": "base64-encoded-client-cert (optional)",
    "keyData": "base64-encoded-client-key (optional)",
    "serverName": "string (optional)"
  },
  "awsAuthConfig": {
    "clusterName": "string (required for EKS)",
    "roleARN": "string (required for EKS IRSA)"
  },
  "execProviderConfig": {
    "command": "string",
    "args": ["array", "of", "strings"],
    "env": {"KEY": "value"},
    "apiVersion": "client.authentication.k8s.io/v1beta1"
  }
}
```

### Authentication Method Priority

ArgoCD tries authentication methods in this order:
1. **Bearer token** (if `bearerToken` is set)
2. **Client certificate** (if `tlsClientConfig.certData` and `keyData` are set)
3. **AWS IRSA** (if `awsAuthConfig` is set and ArgoCD is running in AWS)
4. **Exec provider** (if `execProviderConfig` is set)
5. **In-cluster config** (if server is `https://kubernetes.default.svc`)

---

## Common Patterns

### Pattern 1: In-Cluster (Same cluster as ArgoCD)

```yaml
server: https://kubernetes.default.svc
config: "{}"
```

**Use case:** ArgoCD managing applications in the same cluster it's running in.

### Pattern 2: External Cluster with Cert Auth

```yaml
server: https://external-cluster:6443
config: |
  {
    "tlsClientConfig": {
      "insecure": false,
      "caData": "...",
      "certData": "...",
      "keyData": "..."
    }
  }
```

**Use case:** ArgoCD managing a separate Kubernetes cluster using certificate-based authentication.

### Pattern 3: AWS EKS with IRSA

```yaml
server: https://<eks-endpoint>.eks.amazonaws.com
config: |
  {
    "awsAuthConfig": {
      "clusterName": "my-eks-cluster",
      "roleARN": "arn:aws:iam::account:role/argocd-role"
    },
    "tlsClientConfig": {
      "insecure": false,
      "caData": "..."
    }
  }
```

**Use case:** ArgoCD managing AWS EKS clusters using IAM roles.

---

## Troubleshooting

### Issue: "Unable to connect to cluster"

**Symptoms:** ArgoCD shows cluster as "Unknown" or "Connection Failed"

**Checklist:**
1. Verify server URL is reachable from ArgoCD pod:
   ```bash
   kubectl exec -n argocd deployment/argocd-server -- curl -k <server-url>
   ```
2. Check certificate validity:
   ```bash
   echo "<caData>" | base64 -d | openssl x509 -text -noout
   ```
3. Test credentials separately:
   ```bash
   kubectl --server=<server-url> \
     --certificate-authority=<ca-file> \
     --client-certificate=<cert-file> \
     --client-key=<key-file> \
     get nodes
   ```

### Issue: "x509: certificate signed by unknown authority"

**Cause:** `tlsClientConfig.caData` is missing or incorrect.

**Solution:** Ensure `caData` contains the base64-encoded CA certificate that signed the cluster's server certificate.

### Issue: AWS EKS "Unauthorized"

**Cause:** IAM role not configured correctly or ArgoCD service account not annotated.

**Solution:**
1. Verify IRSA annotation on ArgoCD service account:
   ```bash
   kubectl get sa argocd-application-controller -n argocd -o yaml | grep eks.amazonaws.com/role-arn
   ```
2. Verify IAM role trust policy allows ArgoCD service account
3. Verify IAM role has EKS cluster access in aws-auth ConfigMap

---

## Security Best Practices

1. **Always use TLS verification** (`tlsClientConfig.insecure: false`) in production
2. **Rotate credentials regularly** (client certificates, bearer tokens)
3. **Use least privilege** (RBAC roles for ArgoCD service accounts)
4. **Store sensitive configs in Kubernetes Secrets** (never commit to Git)
5. **Use IRSA for AWS EKS** (avoid long-lived credentials)
6. **Monitor cluster access logs** (detect unauthorized access attempts)

---

## Related Documentation

- [ArgoCD Cluster Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)
- [ArgoCD AWS EKS Integration](https://argo-cd.readthedocs.io/en/stable/operator-manual/argocd-eks-integration/)
- [Kubernetes Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- [AWS IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

---

**Last Updated:** 2026-02-13  
**Source Files:**
- `gitops/clusters/k3s-proxmox.yaml` (TLS client cert example)
- `gitops/clusters/eks-aws.yaml` (AWS auth example)
