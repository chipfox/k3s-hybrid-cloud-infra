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
