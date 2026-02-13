locals {
  argocd_admin_password_mtime = formatdate("YYYY-MM-DD'T'hh:mm:ss'Z'", timestamp())
}

data "aws_secretsmanager_secret" "argocd_admin_password" {
  arn = var.argocd_admin_password_secret_arn
}

data "aws_secretsmanager_secret_version" "argocd_admin_password" {
  secret_id = data.aws_secretsmanager_secret.argocd_admin_password.id
}

resource "aws_iam_role" "argocd_controller" {
  name = "${var.project_name}-argocd-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-application-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "argocd_controller" {
  name = "${var.project_name}-argocd-controller"
  role = aws_iam_role.argocd_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeRole"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "argocd_repo_secret" {
  name = "${var.project_name}-argocd-repo-secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.argocd_repo_credentials_secret_arn
      }
    ]
  })
}

resource "aws_iam_role" "argocd_repo_secret" {
  name = "${var.project_name}-argocd-repo-secret"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-repo-server"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "argocd_repo_secret" {
  role       = aws_iam_role.argocd_repo_secret.name
  policy_arn = aws_iam_policy.argocd_repo_secret.arn
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_secret" "argocd_repo_credentials" {
  metadata {
    name      = "repo-${var.argocd_repo_name}"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }

  data = {
    url = var.argocd_repo_url
  }

  type = "Opaque"
}

resource "kubernetes_secret" "argocd_repo_irsa" {
  metadata {
    name      = "${var.argocd_repo_name}-aws-creds"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }

  data = {
    type          = "git"
    url           = var.argocd_repo_url
    username      = "aws"
    password      = ""
    sshPrivateKey = ""
    secretRef     = data.aws_secretsmanager_secret.argocd_admin_password.arn
  }

  type = "Opaque"
}

resource "kubernetes_secret" "argocd_cluster_secret" {
  metadata {
    name      = "${var.project_name}-eks"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  data = {
    name   = "${var.project_name}-eks"
    server = module.eks.cluster_endpoint
    config = jsonencode({
      tlsClientConfig = {
        insecure = false
        caData   = module.eks.cluster_certificate_authority_data
      }
    })
  }

  type = "Opaque"
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_chart_version

  create_namespace = false

  values = [
    templatefile("${path.module}/argocd-values.yaml", {
      argocd_admin_password_bcrypt = data.aws_secretsmanager_secret_version.argocd_admin_password.secret_string
      argocd_admin_password_mtime  = local.argocd_admin_password_mtime
      argocd_image_tag             = var.argocd_version
      argocd_ingress_cidrs         = join(",", var.argocd_ingress_cidrs)
      argocd_hostname              = var.argocd_hostname
      argocd_controller_role_arn   = aws_iam_role.argocd_controller.arn
      argocd_acm_certificate_arn   = var.argocd_acm_certificate_arn
      argocd_ingress_subnets       = join(",", var.argocd_ingress_subnet_ids)
    })
  ]

  depends_on = [
    kubernetes_namespace.argocd
  ]
}
