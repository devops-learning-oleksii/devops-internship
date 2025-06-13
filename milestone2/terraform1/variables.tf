# Global Variables
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# Security Groups
variable "security_groups" {
  type = map(object({
    ingress_ports       = list(number)
    allowed_cidr_blocks = list(string)
  }))
}

# EC2 Instances
variable "ec2_instances" {
  type = map(object({
    ami            = string
    instance_type  = string
    key_name       = string
    security_group = string
    iam_role       = optional(string)
    subnet_type    = string
    public_ip      = bool
    user_data      = optional(string)
  }))
}

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "key_path" {
  description = "Path to the private key file (key.pem)"
  type        = string
}

# Postgres
variable "instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
}

variable "allocated_storage" {
  description = "The allocated storage in gigabytes"
  type        = number
}

variable "db_name" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_username" {
  type = string
}

variable "ssh_machines" {
  description = "List of machine names to configure SSH access for"
  type        = list(string)
}

variable "ssh_user" {
  description = "SSH user to use for connections"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to the SSH private key file"
  type        = string
}

variable "database_dump_file" {
  description = "Path to the database dump file to restore"
  type        = string
}
