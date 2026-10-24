terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0" # or your preferred version
    }
  }

  backend "s3" {
    bucket       = "devboard-tfstate-565905128295-ap-south-1"
    key          = "dev/eks.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
