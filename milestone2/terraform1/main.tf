provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs              = var.availability_zones
  private_subnets  = var.private_subnet_cidrs
  public_subnets   = var.public_subnet_cidrs
  database_subnets = ["10.2.11.0/24", "10.2.12.0/24"]  # Different CIDR blocks for database subnets

  enable_nat_gateway = true
  single_nat_gateway = true

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
      Name = "${var.environment}-vpc"
    },
    var.tags
  )
}

module "security_groups" {
  source = "terraform-aws-modules/security-group/aws"

  for_each = var.security_groups

  name        = each.key
  description = "Security group for ${each.key}"
  vpc_id      = module.network.vpc_id

  ingress_with_cidr_blocks = [
    for port in each.value.ingress_ports : {
      from_port   = port
      to_port     = port
      protocol    = "tcp"
      description = "Allow port ${port}"
      cidr_blocks = each.value.allowed_cidr_blocks[0] # Take first CIDR block from the list
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
    var.tags
  )
}

module "ec2_instances" {
  source = "terraform-aws-modules/ec2-instance/aws"

  for_each = var.ec2_instances

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
    var.tags
  )
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${var.environment}-db"

  engine            = "postgres"
  engine_version    = "15.13"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  family            = "postgres15"  # Parameter group family

  db_name  = var.db_name
  password = var.db_password
  username = var.db_username
  port     = 5432

  # VPC Configuration
  vpc_security_group_ids = [module.security_groups["database_sg"].security_group_id]
  db_subnet_group_name   = module.network.database_subnet_group_name

  # Security
  multi_az               = false
  publicly_accessible    = false  # Keep database private
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = merge(
    {
      Name = "${var.environment}-db"
    },
    var.tags
  )
}

module "ssh_config" {
  source = "./modules/ssh_config"

  bastion_public_ip = module.ec2_instances["bastion"].public_ip
  machines         = var.ssh_machines
  machine_private_ips = {
    for machine in var.ssh_machines :
    machine => module.ec2_instances[machine].private_ip
  }
  ssh_user     = var.ssh_user
  ssh_key_path = var.ssh_key_path

  depends_on = [module.ec2_instances]
}


