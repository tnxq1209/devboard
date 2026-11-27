
data "aws_caller_identity" "current" {}

locals {
  eks_oidc_issuer = trimprefix(
    data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer,
    "https://"
  )
}

resource "aws_iam_role" "external_secrets" {
  name = "${var.cluster_name}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.eks_oidc_issuer}:aud" = "sts.amazonaws.com"
          "${local.eks_oidc_issuer}:sub" = "system:serviceaccount:external-secrets:external-secrets"
        }
      }
    }]
  })

  tags = {
    Project     = "devboard"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${var.cluster_name}-external-secrets"
  description = "Read DevBoard secrets from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:devboard/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

