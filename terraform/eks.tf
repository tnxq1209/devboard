
data "http" "my_public_ip" {
  url = "https://api.ipify.org"
}

locals {
  current_ip = chomp(data.http.my_public_ip.response_body)
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.24.3"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  #enable_aws_load_balancer_controller = true

  #enable_cluster_autoscaler = true

  aws_load_balancer_controller = {
    set = [
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      }
    ]
  }  

  helm_releases = {
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
              type = "LoadBalancer"
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
                request = {
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
          server = {
            extraArgs = ["--insecure"]
            service = {
              type = "LoadBalancer"
            }
          }
        })
      ]
    }
  }

  tags = {
    Project     = "devboard"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnets

  control_plane_subnet_ids = module.vpc.intra_subnets

  enable_irsa = true

  node_security_group_additional_rules = {
    ingress_self_http = {
      description = "Allow HTTP traffic between EKS nodes"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      self        = true
    }
  }

  endpoint_public_access  = true
  endpoint_private_access = true

  endpoint_public_access_cidrs = [
    "${local.current_ip}/32"
  ]

  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API"

  enabled_log_types = [
    "api",
    "audit",
    "authenticator",
  ]

  cloudwatch_log_group_retention_in_days = 7

  addons = {
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }

    kube-proxy = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }

    vpc-cni = {
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }

    eks-pod-identity-agent = {
      addon_version  = "v1.3.10-eksbuild.3"
      before_compute = true
    }
    metrics-server = {
      most_recent = true
      # Option A: Override port to 4443 to match default EKS module security group rules
      configuration_values = jsonencode({
        containerPort = 4443
      })
    }
  }

  eks_managed_node_groups = {
    default = {
      name               = "default"
      instance_types     = var.node_instance_types
      kubernetes_version = var.kubernetes_version

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      subnet_ids = module.vpc.private_subnets

      labels = {
        Environment = "dev"
        NodeGroup   = "default"
      }
    }
  }

  access_entries = {
    github_actions_app_verifier = {
      principal_arn = "arn:aws:iam::565905128295:role/devboard-terraform-github-actions"
      kubernetes_groups = [
        "devboard-app-verifier"
      ]
    }
  }

  tags = {
    Project     = "devboard"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.cluster_autoscaler_version

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
}
