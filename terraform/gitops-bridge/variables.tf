variable "kubeconfig_path" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "gitops_repo_url" {
  type = string
}

variable "gitops_repo_revision" {
  type    = string
  default = "HEAD"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.7.10"
}

variable "argocd_admin_password" {
  type      = string
  sensitive = true
}

variable "argocd_nodeport_http" {
  type    = number
  default = 30080
}

variable "argocd_nodeport_https" {
  type    = number
  default = 30443
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "argocd_repo_credentials_secret_arn" {
  type    = string
  default = ""
}

variable "argocd_admin_password_secret_arn" {
  type    = string
  default = ""
}
