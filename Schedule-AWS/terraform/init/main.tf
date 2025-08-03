provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "versioned_locked_bucket" {
  bucket              = var.bucket_name
  force_destroy       = false
  object_lock_enabled = true
}

resource "aws_iam_role" "ec2_server" {
  name = "ec2-server"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_server_profile" {
  name = "ec2-server"
  role = aws_iam_role.ec2_server.name
}

resource "aws_iam_role_policy" "ec2_server_inline" {
  name = "ec2-server-route53-policy"
  role = aws_iam_role.ec2_server.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZones",
          "route53:GetChange"
        ],
        Resource = "*"
      }
    ]
  })
}
