variable "aws_region" {
  description = "AWS region to deploy EKS into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for created AWS resources"
  type        = string
  default     = "k3s-hybrid"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "hybrid-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.42.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "bootstrap_secret_name" {
  description = "Name of an AWS Secrets Manager secret to create (example secure secret pattern)"
  type        = string
  default     = "k3s-hybrid/bootstrap"
}

variable "bootstrap_secret_value" {
  description = "Sensitive secret value stored in Secrets Manager (do not commit; set via TF_VAR_bootstrap_secret_value)"
  type        = string
  sensitive   = true
}

variable "argocd_chart_version" {
  description = "Helm chart version for Argo CD"
  type        = string
  default     = "7.7.10"
}

variable "argocd_version" {
  description = "Argo CD app version"
  type        = string
  default     = "v2.13.2"
}

variable "argocd_admin_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Argo CD admin password"
  type        = string
}

variable "argocd_repo_name" {
  description = "Name of the Git repository for Argo CD"
  type        = string
  default     = "argo-apps"
}

variable "argocd_repo_url" {
  description = "URL of the Git repository for Argo CD"
  type        = string
  default     = "https://github.com/chipfox/argo-apps.git"
}

variable "argocd_repo_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Git repository credentials"
  type        = string
}

variable "argocd_ingress_cidrs" {
  description = "CIDR blocks allowed to access Argo CD Ingress"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "argocd_hostname" {
  description = "Hostname for Argo CD Ingress"
  type        = string
  default     = "argocd.example.com"
}

variable "argocd_acm_certificate_arn" {
  description = "ARN of the ACM certificate for Argo CD Ingress"
  type        = string
  default     = ""
}

variable "argocd_ingress_subnet_ids" {
  description = "Subnet IDs for Argo CD Ingress"
  type        = list(string)
  default     = []
}

