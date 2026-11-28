module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.24.3"

  cluster_name      = data.aws_eks_cluster.cluster.name
  cluster_endpoint  = data.aws_eks_cluster.cluster.endpoint
  cluster_version   = data.aws_eks_cluster.cluster.version
  oidc_provider_arn = data.aws_iam_openid_connect_provider.eks.arn

  enable_aws_load_balancer_controller = true

  aws_load_balancer_controller = {
    chart_version = "3.7.0"
    set = [
      {
        name  = "vpcId"
        value = data.terraform_remote_state.network.outputs.vpc_id
      }
    ]
  }

  helm_releases = {
    cluster_autoscaler = {
      name       = "cluster-autoscaler"
      repository = "https://kubernetes.github.io/autoscaler"
      chart      = "cluster-autoscaler"
      namespace  = "kube-system"
      version    = var.cluster_autoscaler_version
      timeout    = 600
      values = [
        yamlencode({
          autoDiscovery = {
            clusterName = var.cluster_name
          }

          rbac = {
            serviceAccount = {
              create = true
              name   = "cluster-autoscaler"

              annotations = {
                "eks.amazonaws.com/role-arn" = module.cluster_autoscaler_irsa.iam_role_arn
              }
            }
          }
        })
      ]
    }

    kube-prometheus-stack = {
      description      = "Prometheus and Grafana monitoring"
      chart            = "kube-prometheus-stack"
      chart_version    = var.kube_prom_stack_version
      repository       = "oci://ghcr.io/prometheus-community/charts"
      namespace        = "monitoring"
      create_namespace = true

      values = [
        yamlencode({
          grafana = {
            persistence = {
              enabled          = true
              type             = "pvc"
              size             = "3Gi"
              storageClassName = "gp3"
            }
            service = {
              type = "ClusterIP"
            }
          }

          prometheus = {
            prometheusSpec = {
              retention = "7d"
              storageSpec = {
                volumeClaimTemplate = {
                  spec = {
                    storageClassName = "gp3"
                    accessModes      = ["ReadWriteOnce"]
                    resources = {
                      requests = {
                        storage = "5Gi"
                      }
                    }
                  }
                }
              }
            }
          }

          alertmanager = {
            alertmanagerSpec = {
              storage = {
                volumeClaimTemplate = {
                  spec = {
                    storageClassName = "gp3"
                    accessModes      = ["ReadWriteOnce"]
                    resources = {
                      requests = {
                        storage = "2Gi"
                      }
                    }
                  }
                }
              }
            }
          }
        })
      ]
    }

    envoy-gateway = {
      description      = "Envoy Gateway"
      chart            = "gateway-helm"
      chart_version    = var.envoy_gateway_chart_version
      repository       = "oci://docker.io/envoyproxy"
      namespace        = "envoy-gateway-system"
      create_namespace = true

      values = [
        yamlencode({
          deployment = {
            envoyGateway = {
              resources = {
                requests = {
                  cpu    = "100m"
                  memory = "128Mi"
                }
                limits = {
                  cpu    = "200m"
                  memory = "256Mi"
                }
              }
            }
          }
        })
      ]
    }

    argocd = {
      description      = "Argo CD GitOps"
      chart            = "argo-cd"
      chart_version    = var.argocd_chart_version
      repository       = "oci://ghcr.io/argoproj/argo-helm"
      namespace        = "argocd"
      create_namespace = true

      values = [
        yamlencode({
          application = {
              instanceLabelKey = "argocd.argoproj.io/instance"
            }
          server = {
            extraArgs = ["--insecure"]
            service = {
              type = "ClusterIP"
            }
          }
        })
      ]
    }

    loki = {
      description      = "Loki log aggregation"
      chart            = "loki"
      chart_version    = var.loki_chart_version
      repository       = "https://grafana-community.github.io/helm-charts"
      namespace        = "monitoring"
      create_namespace = true

      values = [
        file("${path.module}/../../observability/logging/loki-values.yaml")
      ]
    }

    alloy = {
      description      = "Grafana Alloy Kubernetes log collector"
      chart            = "alloy"
      chart_version    = var.alloy_chart_version
      repository       = "https://grafana.github.io/helm-charts"
      namespace        = "monitoring"
      create_namespace = true

      values = [
        file("${path.module}/../../observability/logging/alloy-values.yaml")
      ]
    }
  }

  tags = {
    Project     = "devboard"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
