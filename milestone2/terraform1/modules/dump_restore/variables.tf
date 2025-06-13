variable "database_dump_file" {
  description = "Path to the database dump file"
  type        = string
}

variable "ec2_instance" {
  description = "Name of the EC2 instance to copy dump file to (e.g., backend, frontend)"
  type        = string
}

variable "db_endpoint" {
  description = "Database endpoint (hostname:port)"
  type        = string
}

variable "db_name" {
  description = "Database name to restore to"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "ssh_user" {
  description = "SSH user for EC2 instance"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH private key file"
  type        = string
}
