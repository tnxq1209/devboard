resource "aws_iam_role_policy" "github_actions_app_verifier" {
  name = "devboard-eks-app-verifier"
  role = "devboard-terraform-github-actions"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "eks:DescribeCluster"
        ]

        Resource = "arn:aws:eks:ap-south-1:565905128295:cluster/devboard-eks"
      }
    ]
  })
}