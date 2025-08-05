terraform {}

provider "aws" {
  region = "us-east-1"
}

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "devops-schedule-secret" # Name of you secret
}

locals {
  config            = jsondecode(file("variables.json"))
  global            = local.config.global
  terraform_config  = local.config.terraform

  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )

  ec2_instances_flat = merge([
    for inst_name, inst_conf in local.terraform_config.instances.ec2_instances : {
      for i in range(lookup(inst_conf, "count", 1)) :
        "${inst_name}-${i + 1}" => merge(inst_conf, { index = i + 1, base_name = inst_name })
    }
  ]...)
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.global.environment}-vpc"

  cidr = local.terraform_config.vpc.cidr

  azs = local.terraform_config.vpc.availability_zones
  private_subnets = local.terraform_config.vpc.private_subnet_cidrs
  public_subnets =local.terraform_config.vpc.public_subnet_cidrs
  database_subnets = local.terraform_config.vpc.database_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support = true

  # Database
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

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

  name = each.key
  vpc_id = module.vpc.vpc_id

  ingress_with_cidr_blocks = concat(
      [
          for port in each.value.ingress_ports_tcp : {
              from_port = port
              to_port = port
              protocol = "tcp"
              cidr_blocks = each.value.allowed_cidr_blocks[0]
          }
      ],
      [
          for port in each.value.ingress_ports_udp : {
              from_port = port
              to_port = port
              protocol = "udp"
              cidr_blocks = each.value.allowed_cidr_blocks[0]
          }
      ]
  )

  egress_with_cidr_blocks = [
      {
          from_port = 0
          to_port = 0
          protocol = "-1"
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

module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  for_each = local.ec2_instances_flat

  name = "${each.value.base_name}-node-${each.value.index}"
  ami = each.value.ami
  instance_type = each.value.instance_type
  key_name = each.value.key_name
  vpc_security_group_ids = [module.security_groups[each.value.security_group].security_group_id]
  iam_instance_profile   = each.value.iam_role != "" ? each.value.iam_role : null

  subnet_id = (
      each.value.subnet_type == "public" ? module.vpc.public_subnets[0] : module.vpc.private_subnets[0]
  )

  associate_public_ip_address = each.value.public_ip

  user_data = (each.value.user_data != null && each.value.user_data != "") ? file("${path.module}/user_data/${each.value.user_data}") : null

  tags = merge(
      {
      Name = "instance-${each.key}"
      },
      local.terraform_config.tags
  )

  depends_on = [module.vpc]

}

module "ssh_config" {
  source = "./modules/ssh_config"

  bastion_public_ip = module.ec2_instance["server-1"].public_ip
  machines          = local.terraform_config.ssh.ssh_machines
  machine_private_ips = {
    for machine in local.terraform_config.ssh.ssh_machines :
    machine => module.ec2_instance[machine].private_ip
  }
  ssh_user     = local.terraform_config.ssh.ssh_user
  ssh_key_path = local.terraform_config.ssh.ssh_key_path

  depends_on = [module.ec2_instance]
}

module "db" {
  source = "terraform-aws-modules/rds/aws"
  identifier = "${local.global.environment}-db"

  engine = "postgres"
  engine_version = "15.13"
  instance_class = local.terraform_config.database.instance_class
  allocated_storage = local.terraform_config.database.allocated_storage
  family = "postgres15"

  db_name  = local.db_creds.db_name
  password = local.db_creds.db_password
  username = local.db_creds.db_username
  port = 5432

  vpc_security_group_ids = [module.security_groups["database_sg"].security_group_id]
  db_subnet_group_name = module.vpc.database_subnet_group_name

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

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

# Use aws_route53_zone resource to create zone or just copy your zone id to aws_route53_record resource so NS will be static

# resource "aws_route53_zone" "main" {
#   name = local.terraform_config.domain_name
# }


###
resource "aws_route53_record" "a_records" {
  for_each =  toset(["argo", "monitoring", "api", "@"]) # List of subdomains

  zone_id = local.terraform_config.zone_id #YOUR_ZONE_ID
  name    = each.key == "@" ? local.terraform_config.domain_name : "${each.key}.${local.terraform_config.domain_name}"
  type    = "A"
  ttl     = 300
  records = [module.ec2_instance["server-1"].public_ip]
}

