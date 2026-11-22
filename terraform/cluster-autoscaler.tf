module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                        = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.cluster_autoscaler_version
  timeout    = 600
  values = [
    <<-EOT
    autoDiscovery:
      clusterName: "${module.eks.cluster_name}"
    rbac:
      serviceAccount:
        create: true
        name: "cluster-autoscaler"
        annotations:
          # FIX: Change .iam_role_arn to .arn
          eks.amazonaws.com/role-arn: "${module.cluster_autoscaler_irsa_role.arn}"
    EOT
  ]
  depends_on = [module.eks]
}