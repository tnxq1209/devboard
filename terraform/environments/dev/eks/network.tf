data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "devboard-tfstate-565905128295-ap-south-1"
    key    = "dev/network.tfstate"
    region = var.region
  }
}

