
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

  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  control_plane_subnet_ids = data.terraform_remote_state.network.outputs.intra_subnet_ids
  
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
      addon_version = "v1.14.7-eksbuild.11"
    }

    kube-proxy = {
      addon_version = "v1.37.0-eksbuild.22"
    }

    vpc-cni = {
      addon_version  = "v1.22.4-eksbuild.3"
      before_compute = true
    }

    eks-pod-identity-agent = {
      addon_version  = "v1.3.10-eksbuild.3"
      before_compute = true
    }

    metrics-server = {
      addon_version = "v0.9.0-eksbuild.13"
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

      subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

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

