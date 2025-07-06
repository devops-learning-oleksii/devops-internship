terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "aws-secret-2025-06-27-08-42-51"
}

locals {
  config            = jsondecode(file(var.json_file))
  global            = local.config.global
  terraform_config  = local.config.terraform
  ansible_config    = local.config.ansible
  cloudflare_config = local.config.cloudflare

  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}

provider "aws" {
  region = local.global.aws_region
}

module "network" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.global.environment}-vpc"
  cidr = local.terraform_config.vpc.cidr

  azs              = local.terraform_config.vpc.availability_zones
  private_subnets  = local.terraform_config.vpc.private_subnet_cidrs
  public_subnets   = local.terraform_config.vpc.public_subnet_cidrs
  database_subnets = ["10.2.11.0/24", "10.2.12.0/24"]

  enable_nat_gateway = false
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable database subnet group using database subnets
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # Disable other subnet groups we don't need
  create_elasticache_subnet_group       = false
  create_redshift_subnet_group          = false
  create_elasticache_subnet_route_table = false
  create_redshift_subnet_route_table    = false

  tags = merge(
    {
      Name = "${local.global.environment}-vpc"
    },
    local.terraform_config.tags
  )
}

module "security_groups" {
  source = "terraform-aws-modules/security-group/aws"

  for_each = local.terraform_config.security_groups

  name        = each.key
  description = "Security group for ${each.key}"
  vpc_id      = module.network.vpc_id

  ingress_with_cidr_blocks = [
    for port in each.value.ingress_ports : {
      from_port   = port
      to_port     = port
      protocol    = "tcp"
      description = "Allow port ${port}"
      cidr_blocks = each.value.allowed_cidr_blocks[0]
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
      description = "Allow all outbound traffic"
    }
  ]

  tags = merge(
    {
      Name = each.key
    },
    local.terraform_config.tags
  )
}

module "ec2_instances" {
  source = "terraform-aws-modules/ec2-instance/aws"

  for_each = local.terraform_config.instances.ec2_instances

  name                   = "instance-${each.key}"
  ami                    = each.value.ami
  instance_type          = each.value.instance_type
  key_name               = each.value.key_name
  vpc_security_group_ids = [module.security_groups[each.value.security_group].security_group_id]
  iam_instance_profile   = each.value.iam_role != "" ? each.value.iam_role : null

  subnet_id = (each.value.subnet_type == "public") ? module.network.public_subnets[0] : module.network.private_subnets[0]

  associate_public_ip_address = each.value.public_ip

  user_data = each.value.user_data != null ? file("${path.module}/user_data/${each.value.user_data}") : null

  tags = merge(
    {
      Name = "instance-${each.key}"
    },
    local.terraform_config.tags
  )

  depends_on = [module.network]
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${local.global.environment}-db"

  engine            = "postgres"
  engine_version    = "15.13"
  instance_class    = local.terraform_config.database.instance_class
  allocated_storage = local.terraform_config.database.allocated_storage
  family            = "postgres15" # Parameter group family

  db_name  = local.db_creds.db_name
  password = local.db_creds.db_password
  username = local.db_creds.db_username
  port     = 5432

  # VPC Configuration
  vpc_security_group_ids = [module.security_groups["database_sg"].security_group_id]
  db_subnet_group_name   = module.network.database_subnet_group_name

  # Security
  multi_az            = false
  publicly_accessible = false # Keep database private
  skip_final_snapshot = true
  deletion_protection = false

  # Disable AWS Secrets Manager
  manage_master_user_password = false

  parameters = [
    {
      name  = "rds.force_ssl"
      value = "0"
    }
  ]

  tags = merge(
    {
      Name = "${local.global.environment}-db"
    },
    local.terraform_config.tags
  )
}

module "redis" {
  source  = "cloudposse/elasticache-redis/aws"
  version = "~> 1.4"

  # Use your existing naming convention
  namespace = local.global.environment
  name      = "cache"

  # Network configuration - use your existing VPC and subnets
  availability_zones         = local.terraform_config.vpc.availability_zones
  vpc_id                     = module.network.vpc_id
  allowed_security_group_ids = [module.security_groups["backend_sg"].security_group_id]
  subnets                    = module.network.private_subnets

  # Redis configuration optimized for database caching
  cluster_size      = 1                # Start with single node for dev
  instance_type     = "cache.t3.micro" # Match your other instances
  apply_immediately = true

  family         = "redis7"
  engine_version = "7.0"
  port           = 6379

  # Simplified settings for development
  automatic_failover_enabled = false # Single node doesn't need failover
  multi_az_enabled           = false # Single AZ for dev
  at_rest_encryption_enabled = false # Simplified for dev
  transit_encryption_enabled = false # Easier backend integration

  # Cache-optimized parameters
  parameter = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]

  # Basic backup settings
  snapshot_retention_limit         = 1
  cloudwatch_metric_alarms_enabled = false # Disable for dev

  tags = local.terraform_config.tags

  depends_on = [module.network]
}

module "ssh_config" {
  source = "./modules/ssh_config"

  bastion_public_ip = module.ec2_instances["bastion"].public_ip
  machines          = local.terraform_config.ssh.ssh_machines
  machine_private_ips = {
    for machine in local.terraform_config.ssh.ssh_machines :
    machine => module.ec2_instances[machine].private_ip
  }
  ssh_user     = local.terraform_config.ssh.ssh_user
  ssh_key_path = local.terraform_config.ssh.ssh_key_path

  depends_on = [module.ec2_instances]
}

provider "cloudflare" {}

data "cloudflare_zone" "domain" {
  name = local.cloudflare_config.domain_name
}

resource "cloudflare_record" "monitoring" {
  zone_id = data.cloudflare_zone.domain.id
  name    = local.cloudflare_config.dns_config.monitoring_name
  content = module.ec2_instances["monitoring"].public_ip
  type    = "A"
  ttl     = local.cloudflare_config.dns_config.ttl
  proxied = local.cloudflare_config.dns_config.proxied
}

resource "cloudflare_record" "proxy" {
  zone_id = data.cloudflare_zone.domain.id
  name    = local.cloudflare_config.dns_config.main_record_name
  content = module.ec2_instances["proxy"].public_ip
  type    = "A"
  ttl     = local.cloudflare_config.dns_config.ttl
  proxied = local.cloudflare_config.dns_config.proxied
}
