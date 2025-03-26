provider "aws" {
# this region is required to use ACM (AWS Certificate Manager) with CloudFront
  region = "us-east-1" 
}

terraform {
  backend "s3" {
    bucket         = "terraform-resources-gha"
    region         = "ca-central-1"
    key            = "infrastructure/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-resources-gha-lock"
  }
}