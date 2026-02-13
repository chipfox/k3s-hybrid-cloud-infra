locals {
  apps = {
    bootstrap = file("${path.module}/../../gitops/bootstrap/argocd-bootstrap.yaml")
    addons    = file("${path.module}/../../gitops/addons/addons-applicationset.yaml")
    workloads = file("${path.module}/../../gitops/workloads/workloads-applicationset.yaml")
  }
}

# Generate bcrypt hash for ArgoCD admin password
data "external" "argocd_password_bcrypt" {
  program = ["powershell", "-File", "${path.module}/scripts/bcrypt.ps1", "-Password", var.argocd_admin_password]
}

module "gitops_bridge" {
  source = "gitops-bridge-dev/gitops-bridge/helm"

  cluster = {
    cluster_name = var.cluster_name
    environment  = var.environment
    metadata = {
      addons_repo_url      = var.gitops_repo_url
      addons_repo_revision = var.gitops_repo_revision
    }
    addons = {
      enable_workloads = "true"
    }
  }

  apps = local.apps

  argocd = {
    chart_version = var.argocd_chart_version
    values = [
      templatefile("${path.module}/argocd-values.yaml", {
        ARGOCD_GITOPS_REPO_URL = var.gitops_repo_url
        ARGOCD_NODEPORT_HTTP   = var.argocd_nodeport_http
        ARGOCD_NODEPORT_HTTPS  = var.argocd_nodeport_https
        ARGOCD_ADMIN_PASSWORD  = data.external.argocd_password_bcrypt.result.hash
      })
    ]
  }
}
