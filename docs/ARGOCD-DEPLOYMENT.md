# ArgoCD Application Deployment Guide

**Version:** 1.0  
**ArgoCD Version:** v2.13.2  
**Last Updated:** 2026-02-13

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Methods](#deployment-methods)
   - [Method 1: Declarative Application (Recommended)](#method-1-declarative-application-recommended)
   - [Method 2: ApplicationSet for Multi-Environment](#method-2-applicationset-for-multi-environment)
   - [Method 3: CLI Deployment](#method-3-cli-deployment)
4. [Real-World Examples](#real-world-examples)
   - [Deploying Helm Charts](#deploying-helm-charts)
   - [Deploying Kustomize Applications](#deploying-kustomize-applications)
   - [Deploying Plain YAML Manifests](#deploying-plain-yaml-manifests)
   - [Multi-Environment Deployments](#multi-environment-deployments)
5. [Git Repository Structure](#git-repository-structure)
6. [Sync Policies](#sync-policies)
7. [Health Checks](#health-checks)
8. [Rollback Strategies](#rollback-strategies)
9. [Troubleshooting](#troubleshooting)

---

## Overview

### What is GitOps?

**GitOps** is a modern approach to continuous deployment where Git is the single source of truth for declarative infrastructure and applications. Changes are made via Git commits, and automated systems ensure the cluster state matches the Git repository state.

**Key Principles**:
- **Declarative**: Entire system state described in Git
- **Versioned and immutable**: Git history provides audit trail and rollback capability
- **Pulled automatically**: Controllers pull desired state from Git and reconcile
- **Continuously reconciled**: Drift is detected and corrected automatically

### What is ArgoCD?

**ArgoCD** is a declarative, GitOps continuous delivery tool for Kubernetes. It continuously monitors Git repositories and automatically synchronizes application state with the cluster.

**Key Features**:
- **Automated deployment**: Sync applications from Git to Kubernetes automatically
- **Multi-cluster support**: Manage applications across multiple clusters from single control plane
- **Health assessment**: Monitors application health and detects drift
- **Rollback**: Instant rollback to any Git commit
- **SSO integration**: OIDC, OAuth2, SAML, LDAP support
- **Web UI + CLI**: Visual dashboard and command-line interface

### How It Works in This Cluster

This cluster uses the **App-of-Apps pattern** for bootstrapping:

```
ArgoCD Installation (Terraform)
    ↓
Bootstrap Application (gitops/bootstrap/argocd-bootstrap.yaml)
    ↓
    ├─→ Addons ApplicationSet (gitops/addons/addons-applicationset.yaml)
    │       └─→ Deploys cluster addons (cert-manager, ingress, etc.)
    │
    └─→ Workloads ApplicationSet (gitops/workloads/workloads-applicationset.yaml)
            └─→ Deploys applications (guestbook, etc.)
```

**Flow**:
1. Terraform deploys ArgoCD to the cluster via Helm
2. ArgoCD bootstrap Application syncs itself from Git
3. Bootstrap Application creates ApplicationSets
4. ApplicationSets dynamically generate Applications for each addon/workload
5. Applications continuously sync from Git and heal drift

---

## Prerequisites

### 1. ArgoCD Installed and Accessible

This cluster has ArgoCD pre-installed via Terraform GitOps Bridge module.

**Access ArgoCD UI**:
```bash
# Proxmox k3s cluster
http://<ARGOCD_IP>:<PORT>

# Credentials
Username: admin
Password: <YOUR_PASSWORD>
```

**CLI Login**:
```bash
# Install ArgoCD CLI (if not installed)
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login to ArgoCD
argocd login <ARGOCD_IP>:<PORT> \
  --username admin \
  --password '<YOUR_PASSWORD>' \
  --insecure
```

### 2. kubectl Access

You need `kubectl` configured to access the cluster:

```bash
export KUBECONFIG=k3s-ansible/kubeconfig
kubectl get nodes
kubectl get pods -n argocd
```

### 3. Git Repository Access

ArgoCD needs read access to your Git repository. This cluster uses:

**Repository**: `https://github.com/YOUR_ORG/k3s-hybrid-cloud-infra.git`  
**Path**: `gitops/`

For private repositories, configure credentials in ArgoCD:

```bash
# Via CLI
argocd repo add https://github.com/YOUR_ORG/k3s-hybrid-cloud-infra.git \
  --username YOUR_USERNAME \
  --password YOUR_PAT

# Via UI
Settings → Repositories → Connect Repo
```

---

## Deployment Methods

### Method 1: Declarative Application (Recommended)

The **declarative approach** creates an Application manifest in Git. ArgoCD continuously monitors and syncs.

**Use Case**: Production workloads, infrastructure components, GitOps-native workflows.

#### Step-by-Step

**1. Create Application Manifest**

Create `gitops/workloads/my-app/application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/k3s-hybrid-cloud-infra.git
    targetRevision: HEAD
    path: gitops/workloads/my-app/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**2. Create Application Manifests**

Create `gitops/workloads/my-app/manifests/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: nginx:1.21
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

**3. Commit and Push**

```bash
git add gitops/workloads/my-app/
git commit -m "feat: add my-app application"
git push origin main
```

**4. Apply Bootstrap Application (if not already done)**

ArgoCD will automatically detect and sync the new application if bootstrap ApplicationSet is configured to watch `gitops/workloads/*/application.yaml`.

Alternatively, manually apply:

```bash
kubectl apply -f gitops/workloads/my-app/application.yaml
```

**5. Verify Deployment**

```bash
# Check Application status
argocd app get my-app

# Check Kubernetes resources
kubectl get all -n my-app
```

**6. Monitor in UI**

Open ArgoCD UI → Applications → `my-app`

You should see:
- **Status**: Synced + Healthy
- **Resources**: Deployment, Service, Pods
- **History**: Git commit that triggered sync

---

### Method 2: ApplicationSet for Multi-Environment

**ApplicationSets** generate multiple Applications from a single template. Ideal for deploying the same app to multiple environments or clusters.

**Use Case**: Dev/Staging/Prod deployments, multi-cluster workloads, monorepo management.

#### Example: Deploy to Multiple Environments

**1. Create ApplicationSet**

Create `gitops/workloads/my-app-set.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app-multi-env
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: dev
        replicas: "1"
      - env: staging
        replicas: "2"
      - env: production
        replicas: "3"
  template:
    metadata:
      name: 'my-app-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/YOUR_ORG/k3s-hybrid-cloud-infra.git
        targetRevision: HEAD
        path: gitops/workloads/my-app/overlays/{{env}}
      destination:
        server: https://kubernetes.default.svc
        namespace: 'my-app-{{env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

**2. Create Environment Overlays (Kustomize)**

```
gitops/workloads/my-app/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml
    └── production/
        ├── kustomization.yaml
        └── patch-replicas.yaml
```

**`base/kustomization.yaml`**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
```

**`overlays/dev/kustomization.yaml`**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../base
patches:
- patch-replicas.yaml
namespace: my-app-dev
```

**`overlays/dev/patch-replicas.yaml`**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
```

**3. Apply ApplicationSet**

```bash
kubectl apply -f gitops/workloads/my-app-set.yaml
```

**4. Verify**

```bash
# Check generated Applications
argocd app list | grep my-app

# Output:
# my-app-dev         Synced  Healthy  https://kubernetes.default.svc  my-app-dev
# my-app-staging     Synced  Healthy  https://kubernetes.default.svc  my-app-staging
# my-app-production  Synced  Healthy  https://kubernetes.default.svc  my-app-production
```

---

### Method 3: CLI Deployment

**CLI deployment** creates Applications directly via `argocd app create`. Useful for testing and one-off deployments.

**Use Case**: Quick testing, debugging, temporary deployments.

#### Example: Deploy Guestbook

```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace guestbook \
  --sync-policy automated \
  --auto-prune \
  --self-heal \
  --sync-option CreateNamespace=true
```

**Verify**:
```bash
argocd app get guestbook
argocd app sync guestbook  # Manual sync
```

**Delete**:
```bash
argocd app delete guestbook --cascade
```

---

## Real-World Examples

### Deploying Helm Charts

ArgoCD natively supports Helm charts from Helm repositories or Git.

#### Example: Deploy cert-manager from Helm Repository

**1. Create Application Manifest**

Create `gitops/addons/cert-manager/application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
spec:
  project: default
  source:
    chart: cert-manager
    repoURL: https://charts.jetstack.io
    targetRevision: v1.13.3
    helm:
      releaseName: cert-manager
      values: |
        installCRDs: true
        global:
          leaderElection:
            namespace: cert-manager
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**2. Apply**

```bash
kubectl apply -f gitops/addons/cert-manager/application.yaml
```

**3. Verify**

```bash
argocd app get cert-manager
kubectl get pods -n cert-manager
```

#### Example: Deploy Helm Chart from Git with Custom Values

**1. Store Custom Values in Git**

Create `gitops/addons/nginx-ingress/values.yaml`:

```yaml
controller:
  replicaCount: 2
  service:
    type: NodePort
    nodePorts:
      http: 30080
      https: 30443
```

**2. Create Application**

Create `gitops/addons/nginx-ingress/application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-ingress
  namespace: argocd
spec:
  project: default
  source:
    chart: ingress-nginx
    repoURL: https://kubernetes.github.io/ingress-nginx
    targetRevision: 4.8.3
    helm:
      releaseName: nginx-ingress
      valueFiles:
      - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Note**: ArgoCD will read `values.yaml` from the **same repository** as the Application manifest, not from the Helm chart repository.

---

### Deploying Kustomize Applications

ArgoCD auto-detects Kustomize if a `kustomization.yaml` file exists in the source path.

#### Example: Deploy with Base + Overlays

**1. Repository Structure**

```
gitops/workloads/webapp/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── kustomization.yaml
└── overlays/
    └── production/
        ├── kustomization.yaml
        ├── patch-replicas.yaml
        └── patch-image.yaml
```

**`base/kustomization.yaml`**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
- configmap.yaml
commonLabels:
  app: webapp
```

**`overlays/production/kustomization.yaml`**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../base
namespace: webapp-prod
patches:
- patch-replicas.yaml
- patch-image.yaml
images:
- name: webapp
  newTag: v1.2.3
```

**2. Create Application**

Create `gitops/workloads/webapp/application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/k3s-hybrid-cloud-infra.git
    targetRevision: HEAD
    path: gitops/workloads/webapp/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**3. Apply and Verify**

```bash
kubectl apply -f gitops/workloads/webapp/application.yaml
argocd app get webapp-prod
```

---

### Deploying Plain YAML Manifests

For simple applications without Helm or Kustomize.

#### Example: Deploy Static Manifests

**1. Create Manifests**

Create `gitops/workloads/static-site/manifests/`:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: static-site
spec:
  replicas: 2
  selector:
    matchLabels:
      app: static-site
  template:
    metadata:
      labels:
        app: static-site
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: static-site
spec:
  selector:
    app: static-site
  ports:
  - port: 80
  type: ClusterIP
---
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: static-site
spec:
  rules:
  - host: static.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: static-site
            port:
              number: 80
```

**2. Create Application**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: static-site
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/k3s-hybrid-cloud-infra.git
    targetRevision: HEAD
    path: gitops/workloads/static-site/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: static-site
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

### Multi-Environment Deployments

#### Pattern 1: Git Branch per Environment

**Repository Structure**:
```
branches:
  - main (production)
  - staging
  - dev
```

**ApplicationSet**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-branch-app
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - branch: main
        env: production
      - branch: staging
        env: staging
      - branch: dev
        env: dev
  template:
    metadata:
      name: 'myapp-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/YOUR_ORG/myapp-manifests.git
        targetRevision: '{{branch}}'
        path: manifests
      destination:
        server: https://kubernetes.default.svc
        namespace: 'myapp-{{env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

#### Pattern 2: Directory per Environment (Recommended)

**Repository Structure**:
```
gitops/workloads/myapp/
├── dev/
├── staging/
└── production/
```

**ApplicationSet with Git Directory Generator**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-environments
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/YOUR_ORG/k3s-hybrid-cloud-infra.git
      revision: HEAD
      directories:
      - path: gitops/workloads/myapp/*
  template:
    metadata:
      name: 'myapp-{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/YOUR_ORG/k3s-hybrid-cloud-infra.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'myapp-{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

---

## Git Repository Structure

### Recommended Structure (Monorepo)

This cluster uses a **monorepo structure** with clear separation between bootstrap, addons, and workloads:

```
gitops/
├── bootstrap/
│   └── argocd-bootstrap.yaml        # App-of-apps root Application
├── addons/
│   ├── addons-applicationset.yaml   # ApplicationSet for cluster addons
│   ├── cert-manager/
│   │   └── application.yaml
│   ├── ingress-nginx/
│   │   ├── application.yaml
│   │   └── values.yaml
│   └── sealed-secrets/
│       └── application.yaml
├── workloads/
│   ├── workloads-applicationset.yaml  # ApplicationSet for applications
│   ├── guestbook/
│   │   └── application.yaml
│   └── webapp/
│       ├── base/
│       ├── overlays/
│       └── application.yaml
└── clusters/
    ├── k3s-proxmox.yaml             # Cluster registration secret
    └── eks-aws.yaml
```

### Best Practices

**1. Separate Config from Source Code**
- **Config Repo** (this repo): Kubernetes manifests, Helm values, Application definitions
- **Source Repo**: Application source code, Dockerfiles
- **Benefits**: Clean audit logs, no CI triggers for config changes

**2. Use Meaningful Directory Names**
- Environment names: `dev`, `staging`, `production` (not `env1`, `env2`)
- Application names: Match Kubernetes resource names for clarity

**3. Keep Manifests DRY (Don't Repeat Yourself)**
- Use Kustomize base + overlays for environment differences
- Use Helm values files for configuration
- Use ApplicationSets for repetitive Applications

**4. Store Secrets Properly**
- **Never commit plaintext secrets** to Git
- Use **Sealed Secrets**, **External Secrets Operator**, or **SOPS**
- This cluster uses Terraform to manage ArgoCD admin password (bcrypt hashed)

**5. Pin Versions**
- Helm charts: Use specific `targetRevision: v1.2.3` (not `latest`)
- Container images: Tag with version or SHA (not `:latest`)
- Git: Use commit SHAs for production (not `HEAD`)

---

## Sync Policies

### Automated vs Manual Sync

**Automated Sync** (Recommended for Production):
```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in Git
    selfHeal: true   # Revert manual changes
    allowEmpty: false  # Prevent deleting all resources
```

**Benefits**:
- ✅ Continuous reconciliation (drift correction)
- ✅ No manual intervention required
- ✅ Git is single source of truth

**Use Cases**: Production workloads, stable infrastructure, GitOps-native teams

---

**Manual Sync** (Default):
```yaml
syncPolicy:
  automated: {}  # or omit entirely
```

**Benefits**:
- ✅ Control over deployment timing
- ✅ Review changes before applying
- ✅ Safer for testing/debugging

**Use Cases**: Development environments, sensitive changes, debugging

**Manual Sync Command**:
```bash
argocd app sync my-app
```

---

### Prune Resources

**`prune: true`** deletes resources removed from Git:

```yaml
syncPolicy:
  automated:
    prune: true
```

**Example**:
1. Git has: `deployment.yaml`, `service.yaml`, `ingress.yaml`
2. ArgoCD syncs → 3 resources in cluster
3. You delete `ingress.yaml` from Git
4. ArgoCD syncs → Ingress resource deleted from cluster

**Disable pruning for specific resources**:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
```

**Use Case**: Prevent deletion of StatefulSet PVCs, manually-managed resources.

---

### Self-Heal

**`selfHeal: true`** reverts manual changes to cluster:

```yaml
syncPolicy:
  automated:
    selfHeal: true
```

**Example**:
1. Git defines `replicas: 3`
2. Someone manually runs `kubectl scale deployment my-app --replicas=5`
3. ArgoCD detects drift and reverts to `replicas: 3`

**When to Disable**:
- Debugging (need to manually change resources temporarily)
- HPA (Horizontal Pod Autoscaler) managed resources
- Resources with `status` fields that change frequently

---

### Sync Options

**Common Sync Options**:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true     # Auto-create destination namespace
    - PrunePropagationPolicy=foreground  # Wait for resources to delete before proceeding
    - PruneLast=true          # Prune resources after all other sync operations
    - Replace=true            # Use kubectl replace instead of apply
    - ServerSideApply=true    # Use server-side apply (beta)
```

**Example: Wait for StatefulSet deletion**:
```yaml
syncPolicy:
  syncOptions:
    - PrunePropagationPolicy=foreground
```

---

### Progressive Syncs (Beta - v2.6.0+)

**Progressive Syncs** deploy resources in waves, waiting for health before proceeding:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
spec:
  strategy:
    type: RollingSync
    rollingSync:
      steps:
      - matchExpressions:
        - key: app
          operator: In
          values:
          - cert-manager
      - matchExpressions:
        - key: app
          operator: In
          values:
          - ingress-nginx
      - matchExpressions:
        - key: app
          operator: In
          values:
          - sealed-secrets
```

**Flow**:
1. Deploy cert-manager → wait for Healthy
2. Deploy ingress-nginx → wait for Healthy
3. Deploy sealed-secrets → wait for Healthy

**Use Case**: Ordered deployment of interdependent addons.

---

## Health Checks

ArgoCD continuously monitors application health using Kubernetes resource status.

### Built-in Health Checks

**Deployment/ReplicaSet/StatefulSet/DaemonSet**:
- ✅ **Healthy**: All replicas available, no restarts
- 🔄 **Progressing**: Rolling update in progress
- ❌ **Degraded**: Replicas unavailable, CrashLoopBackOff

**Service (LoadBalancer)**:
- ✅ **Healthy**: `status.loadBalancer.ingress` populated
- 🔄 **Progressing**: Waiting for external IP

**Ingress**:
- ✅ **Healthy**: `status.loadBalancer.ingress` populated

**Job**:
- ✅ **Healthy**: Job completed successfully
- ❌ **Degraded**: Job failed

**CronJob**:
- ✅ **Healthy**: Last scheduled job succeeded
- 🔄 **Progressing**: Job currently running
- ❌ **Degraded**: Last scheduled job failed

---

### Custom Health Checks (Lua Scripts)

For custom resources (CRDs), define health checks in `argocd-cm` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.health.myapp.io_MyResource: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.conditions ~= nil then
        for i, condition in ipairs(obj.status.conditions) do
          if condition.type == "Ready" and condition.status == "True" then
            hs.status = "Healthy"
            hs.message = condition.message
            return hs
          end
        end
      end
    end
    hs.status = "Progressing"
    hs.message = "Waiting for resource to be ready"
    return hs
```

**Apply**:
```bash
kubectl apply -f argocd-cm.yaml
kubectl rollout restart deployment argocd-application-controller -n argocd
```

---

### Health Status Levels

| Status | Icon | Meaning |
|--------|------|---------|
| **Healthy** | ✅ | Resource functioning correctly |
| **Progressing** | 🔄 | Resource being updated/created |
| **Degraded** | ❌ | Resource not functioning correctly |
| **Suspended** | ⏸️ | Resource paused (e.g., CronJob) |
| **Missing** | ❓ | Resource does not exist in cluster |
| **Unknown** | ❔ | Health cannot be determined |

---

### Checking Application Health

**CLI**:
```bash
# Check overall health
argocd app get my-app

# Check individual resource health
argocd app resources my-app

# Watch sync status
argocd app wait my-app --health
```

**UI**:
- Open ArgoCD → Applications → `my-app`
- View resource tree with health indicators
- Click resources for detailed status

---

## Rollback Strategies

### Strategy 1: Git Revert (Recommended)

Rollback by reverting Git commit:

```bash
# View history
git log --oneline

# Revert to previous commit
git revert HEAD

# Push revert
git push origin main
```

**ArgoCD automatically syncs the revert.**

**Benefits**:
- ✅ Git history preserved (shows rollback in audit log)
- ✅ No manual kubectl commands
- ✅ Works across multiple clusters
- ✅ Can be automated via CI/CD

---

### Strategy 2: ArgoCD UI Rollback

Rollback via ArgoCD UI:

1. Open Application → **History** tab
2. Select previous sync
3. Click **Rollback**
4. Confirm

**This temporarily syncs to old Git commit. Git remains unchanged.**

---

### Strategy 3: ArgoCD CLI Rollback

```bash
# View sync history
argocd app history my-app

# Rollback to specific revision
argocd app rollback my-app <revision-id>
```

**Example**:
```bash
$ argocd app history guestbook
ID  DATE                           REVISION
0   2026-02-13 10:15:23 -0800 PST  a1b2c3d (main)
1   2026-02-13 09:30:11 -0800 PST  x7y8z9w (main)

$ argocd app rollback guestbook 1
```

---

### Strategy 4: Manual kubectl Rollback

For Deployments only:

```bash
kubectl rollout undo deployment/my-app -n my-app-ns
```

**⚠️ Warning**: ArgoCD will detect drift and revert this change if `selfHeal: true`.

---

### Best Practices

1. **Always use Git revert** for production rollbacks (audit trail)
2. **Test rollbacks in dev/staging** before production
3. **Monitor health after rollback** (verify no cascading failures)
4. **Document rollback reason** in Git commit message

---

## Troubleshooting

### Issue 1: Application Stuck in "OutOfSync"

**Symptoms**:
- Application shows **OutOfSync** status
- Resources in cluster differ from Git

**Diagnosis**:
```bash
# Check sync status
argocd app get my-app

# View diff
argocd app diff my-app
```

**Solutions**:

**A. Manual kubectl changes detected**:
```bash
# Revert manual changes by syncing from Git
argocd app sync my-app
```

**B. Git not pulled**:
```bash
# Force refresh from Git
argocd app get my-app --refresh
```

**C. Webhook not configured**:
```bash
# Configure Git webhook to notify ArgoCD on push
# Settings → Repositories → <repo> → Configure Webhook
```

---

### Issue 2: Application Stuck in "Progressing"

**Symptoms**:
- Application shows **Progressing** status indefinitely
- Resources not reaching Healthy state

**Diagnosis**:
```bash
# Check resource status
argocd app resources my-app

# Check pod logs
kubectl logs -n my-app-ns deployment/my-app
```

**Common Causes**:

**A. Image pull failure**:
```bash
kubectl describe pod <pod-name> -n my-app-ns
# Look for: "Failed to pull image" or "ImagePullBackOff"
```

**Solution**: Fix image name/tag in Git, verify registry credentials.

**B. Insufficient resources (CPU/memory)**:
```bash
kubectl describe nodes
# Look for: "Insufficient cpu" or "Insufficient memory"
```

**Solution**: Scale down replicas or add cluster nodes.

**C. Liveness/readiness probe failure**:
```bash
kubectl describe pod <pod-name> -n my-app-ns
# Look for: "Liveness probe failed" or "Readiness probe failed"
```

**Solution**: Fix probe configuration or app health endpoint.

---

### Issue 3: Sync Failed

**Symptoms**:
- Application shows **SyncFailed** status
- Error message in UI/CLI

**Diagnosis**:
```bash
argocd app get my-app
argocd app logs my-app
```

**Common Errors**:

**A. "manifest collision"**:
```
Error: rendered manifests contain a resource that already exists
```

**Solution**: Resource already exists in cluster. Add to `.spec.source.helm.skipCrds: true` or delete manually.

**B. "validation failed"**:
```
Error: error validating data: ValidationError(Deployment.spec.replicas)
```

**Solution**: Fix manifest syntax error in Git.

**C. "permission denied"**:
```
Error: deployments.apps is forbidden: User "system:serviceaccount:argocd:argocd-application-controller" cannot create resource
```

**Solution**: Grant RBAC permissions to ArgoCD service account.

---

### Issue 4: Authentication Errors

**Symptoms**:
- "repository not found" or "authentication failed"

**Diagnosis**:
```bash
argocd repo list
```

**Solutions**:

**A. Repository not registered**:
```bash
argocd repo add https://github.com/YOUR_ORG/k3s-hybrid-cloud-infra.git \
  --username YOUR_USERNAME \
  --password YOUR_PAT
```

**B. SSH key expired/invalid**:
```bash
# Register SSH key
argocd repo add git@github.com:YOUR_ORG/k3s-hybrid-cloud-infra.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

**C. Helm repository authentication**:
```bash
argocd repo add https://charts.example.com \
  --type helm \
  --username admin \
  --password secret
```

---

### Issue 5: Resources Not Pruning

**Symptoms**:
- Deleted resources from Git remain in cluster
- `prune: true` not working

**Diagnosis**:
```bash
argocd app get my-app --show-operation
```

**Solutions**:

**A. Verify prune is enabled**:
```yaml
syncPolicy:
  automated:
    prune: true  # Ensure this is set
```

**B. Check resource annotations**:
```bash
kubectl get deployment my-app -n my-app-ns -o yaml | grep "argocd.argoproj.io/sync-options"
```

If output shows `Prune=false`, remove annotation.

**C. Finalizers blocking deletion**:
```bash
kubectl get deployment my-app -n my-app-ns -o yaml | grep finalizers
```

**Solution**: Remove finalizers manually:
```bash
kubectl patch deployment my-app -n my-app-ns -p '{"metadata":{"finalizers":[]}}' --type=merge
```

---

### Issue 6: High CPU/Memory Usage (ArgoCD Components)

**Symptoms**:
- ArgoCD application-controller or repo-server using excessive resources
- Slow UI/CLI responses

**Diagnosis**:
```bash
kubectl top pods -n argocd
kubectl describe pod argocd-application-controller-0 -n argocd
```

**Solutions**:

**A. Large monorepo**:
- Increase application-controller resources:
```yaml
# Helm values
controller:
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi
```

**B. Too many Applications**:
- Increase `ARGOCD_RECONCILIATION_TIMEOUT`
- Use ApplicationSets to consolidate

**C. Frequent Git polling**:
- Configure Git webhooks to reduce polling
- Increase `timeout.reconciliation` in `argocd-cm`

---

### Debugging Commands

```bash
# Check Application status
argocd app get <app-name>

# View sync history
argocd app history <app-name>

# View diff between Git and cluster
argocd app diff <app-name>

# View logs
argocd app logs <app-name>

# Force refresh from Git
argocd app get <app-name> --refresh

# Manually sync
argocd app sync <app-name>

# Dry-run sync (preview changes)
argocd app sync <app-name> --dry-run

# Check resource health
argocd app resources <app-name>

# Delete and recreate Application
argocd app delete <app-name>
kubectl apply -f application.yaml

# Check ArgoCD component logs
kubectl logs -n argocd deployment/argocd-application-controller
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-repo-server
```

---

## Additional Resources

### Official Documentation
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/en/stable/
- **Best Practices**: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/
- **Troubleshooting**: https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/

### Tutorials
- **Codefresh ArgoCD Guide**: https://codefresh.io/learn/argo-cd/
- **OneUptime ArgoCD Series**: https://oneuptime.com/blog/
- **DevToolbox Complete Guide**: https://devtoolbox.dedyn.io/blog/argocd-complete-guide

### Example Repositories
- **IBM GitOps Template**: https://github.com/IBM/template-argocd-gitops
- **ArgoCD Example Apps**: https://github.com/argoproj/argocd-example-apps
- **Production GitOps Tools**: https://github.com/production-gitops-public/argocd-tools

---

## Support

For issues specific to this cluster:

1. **Check cluster status**:
   ```bash
   kubectl get pods -n argocd
   kubectl get applications -n argocd
   ```

2. **Review recent changes**:
   ```bash
   git log --oneline --since="24 hours ago"
   ```

3. **Check ArgoCD UI**: http://<ARGOCD_IP>:<PORT>

4. **Consult troubleshooting guide** (above)

For ArgoCD bugs or feature requests:
- **GitHub Issues**: https://github.com/argoproj/argo-cd/issues
- **Slack Community**: https://argoproj.github.io/community/join-slack

---

**End of Guide**
