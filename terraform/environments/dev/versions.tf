terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket       = "devboard-tfstate-565905128295-ap-south-1"
    key          = "dev/devboard.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
