terraform {
  backend "s3" {
    bucket       = "aws--terraform-bucket"
    key          = "AWS/terraform-states/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
