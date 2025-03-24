provider "aws" {
 region = "us-east-1" # to use ACM with CloudFront
}

terraform {
  backend "s3" {
    bucket         = "tf-resources-gha"
    region         = "us-east-1"
    key            = "github-actions/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "tf-resources-gha-lock"
  }
}
