provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "versioned_locked_bucket" {
  bucket              = var.bucket_name
  force_destroy       = false
  object_lock_enabled = true
}