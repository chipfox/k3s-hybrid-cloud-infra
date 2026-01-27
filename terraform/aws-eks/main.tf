data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Simple subnetting: 3 public + 3 private
  public_subnets  = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Project = var.project_name
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    default = {
      name           = "${var.project_name}-ng"
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      subnet_ids     = module.vpc.private_subnets
    }
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret" "bootstrap" {
  name = var.bootstrap_secret_name

  tags = {
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "bootstrap" {
  secret_id     = aws_secretsmanager_secret.bootstrap.id
  secret_string = var.bootstrap_secret_value
}
