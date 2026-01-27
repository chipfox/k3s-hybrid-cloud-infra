output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_region" {
  value = var.aws_region
}

output "bootstrap_secret_arn" {
  value = aws_secretsmanager_secret.bootstrap.arn
}
