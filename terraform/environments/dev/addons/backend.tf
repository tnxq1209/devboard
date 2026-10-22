terraform {
  backend "s3" {
    bucket       = "devboard-tfstate-565905128295-ap-south-1"
    key          = "dev/addons/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}

