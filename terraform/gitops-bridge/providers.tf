locals {
  kubeconfig  = yamldecode(file(var.kubeconfig_path))
  api_server  = local.kubeconfig.clusters[0].cluster.server
  cluster_ca  = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
  client_cert = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
  client_key  = base64decode(local.kubeconfig.users[0].user["client-key-data"])
}

provider "kubernetes" {
  host                   = local.api_server
  cluster_ca_certificate = local.cluster_ca
  client_certificate     = local.client_cert
  client_key             = local.client_key
}

provider "helm" {
  kubernetes {
    host                   = local.api_server
    cluster_ca_certificate = local.cluster_ca
    client_certificate     = local.client_cert
    client_key             = local.client_key
  }
}

provider "aws" {
  region = var.aws_region
}
