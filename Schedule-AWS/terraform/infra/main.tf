terraform {}

provider "aws" {
  region = "us-east-1"
}

locals {
  config            = jsondecode(file("variables.json"))
  global            = local.config.global
  terraform_config  = local.config.terraform

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

    enable_nat_gateway = false
    single_nat_gateway = false

    enable_dns_hostnames = true
    enable_dns_support = true

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

    subnet_id = (
        each.value.subnet_type == "public" ? module.vpc.public_subnets[0] : module.vpc.private_subnets[0]
    )

    associate_public_ip_address = each.value.public_ip

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