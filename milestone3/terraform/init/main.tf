provider "aws" {
  region = var.aws_region
}

locals {
  secret_content = jsondecode(file("${path.module}/secrets.json"))
  timestamp      = formatdate("YYYY-MM-DD-HH-mm-ss", timestamp())
  secret_name    = "aws-secret-${local.timestamp}"
  bucket_name    = "aws-bucket-${local.timestamp}"
}

resource "aws_secretsmanager_secret" "timestamp_secret" {
  name = local.secret_name
}

resource "aws_secretsmanager_secret_version" "timestamp_secret_version" {
  secret_id     = aws_secretsmanager_secret.timestamp_secret.id
  secret_string = jsonencode(local.secret_content)
}

resource "aws_s3_bucket" "versioned_locked_bucket" {
  bucket              = local.bucket_name
  force_destroy       = false
  object_lock_enabled = true
}

# backend
resource "aws_iam_role" "ec2_backend" {
  name = "ec2-backend"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_backend_profile" {
  name = "ec2-backend"
  role = aws_iam_role.ec2_backend.name
}

resource "aws_iam_role_policy" "ec2_backend_inline" {
  name = "ec2-backend-inline-policy"
  role = aws_iam_role.ec2_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "rds:DescribeDBInstances",
          "elasticache:DescribeCacheClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_backend_s3_readonly" {
  role       = aws_iam_role.ec2_backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# frontend
resource "aws_iam_role" "ec2_frontend" {
  name = "ec2-frontend"
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

resource "aws_iam_instance_profile" "ec2_frontend_profile" {
  name = "ec2-frontend"
  role = aws_iam_role.ec2_frontend.name
}

resource "aws_iam_role_policy" "ec2_frontend_inline" {
  name = "ec2-frontend-inline-policy"
  role = aws_iam_role.ec2_frontend.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ],
        Resource = "*"
      }
    ]
  })
}

# proxy
resource "aws_iam_role" "ec2-proxy" {
  name = "ec2-proxy"
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

resource "aws_iam_instance_profile" "ec2-proxy_profile" {
  name = "ec2-proxy"
  role = aws_iam_role.ec2-proxy.name
}

resource "aws_iam_role_policy" "ec2-proxy_inline" {
  name = "ec2-proxy-inline-policy"
  role = aws_iam_role.ec2-proxy.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances"
        ],
        Resource = "*"
      }
    ]
  })
}
