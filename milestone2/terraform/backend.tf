terraform {
  backend "s3" {
    bucket       = "your_bucket_name"
    key          = "AWS/terraform-states/terraform.tfstate"
    region       = "your_region"
    encrypt      = true
    use_lockfile = true
  }
}
