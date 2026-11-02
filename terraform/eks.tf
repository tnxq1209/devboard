data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "http" "my_public_ip" {
  url = "https://api.ipify.org"
}

locals {
  current_ip = chomp(data.http.my_public_ip.response_body)
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
      resolve_conflicts_on_update = "PRESERVE"    }

    vpc-cni = {
      before_compute              = true 
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }

    eks-pod-identity-agent = {
      addon_version  = "v1.3.10-eksbuild.3"
      before_compute = true
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

      enable_cluster_autoscaler = true

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




