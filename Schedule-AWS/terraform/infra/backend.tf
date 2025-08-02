terraform {
  backend "s3" {
    bucket       = "devops-schedule-s3" # your s3 bucket name
    key          = "AWS/terraform-states/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
