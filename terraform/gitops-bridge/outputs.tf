output "argocd_endpoint" {
  value = "https://${var.cluster_name}:${var.argocd_nodeport_https}"
}
