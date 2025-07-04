terraform {
  backend "s3" {
    bucket       = "aws-bucket-2025-06-27-08-42-51"
    key          = "AWS/terraform-states/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
