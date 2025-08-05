provider "aws" {
  region = var.aws_region
}

locals {
  secret_content = jsondecode(file("${path.module}/secrets.json"))
}

resource "aws_secretsmanager_secret" "timestamp_secret" {
  name = var.secret_name
}

resource "aws_secretsmanager_secret_version" "timestamp_secret_version" {
  secret_id     = aws_secretsmanager_secret.timestamp_secret.id
  secret_string = jsonencode(local.secret_content)
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
          "route53:GetChange",
          "secretsmanager:GetSecretValue",
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "rds:DescribeDBInstances",
          "elasticache:DescribeCacheClusters"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_server_s3_readonly" {
  role       = aws_iam_role.ec2_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
