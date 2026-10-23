provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "devboard"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
