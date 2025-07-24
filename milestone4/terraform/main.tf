terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "devops-4947-oleksii"
    prefix = "terraform/state"
  }
}

locals {
  config     = jsondecode(file("variables.json"))
  terraform  = local.config.terraform
  ssh        = local.config.ssh
  cloudflare = local.config.cloudflare
}

provider "google" {
  credentials = file("terraform-sa-key.json")
  project     = local.terraform.project_id
  region      = local.terraform.region
}

module "network" {
  source            = "./modules/network"
  region            = local.terraform.region
  public_tcp_ports  = local.terraform.public_tcp_ports
  public_udp_ports  = local.terraform.public_udp_ports
  private_tcp_ports = local.terraform.private_tcp_ports
  private_udp_ports = local.terraform.private_udp_ports
}

module "compute" {
  source            = "./modules/compute"
  instances         = local.terraform.instances
  network_id        = module.network.network_id
  public_subnet_id  = module.network.public_subnet_id
  private_subnet_id = module.network.private_subnet_id
  zone              = local.terraform.zone
}

module "ssh_config" {
  source = "./modules/ssh_config"

  bastion_public_ip = module.compute.vms["server-node-1"].network_interface[0].access_config[0].nat_ip
  machines          = local.ssh.machines
  machine_private_ips = {
    for machine in local.ssh.machines :
    machine => module.compute.vms[machine].network_interface[0].network_ip
  }
  ssh_user     = local.ssh.ssh_user
  ssh_key_path = local.ssh.ssh_key_path
}

provider "cloudflare" {}

module "dns" {
  source      = "./modules/dns"
  domain_name = local.cloudflare.domain_name
  names       = [local.cloudflare.api_name, local.cloudflare.main_record_name, local.cloudflare.monitoring_name, local.cloudflare.argo_name]
  content     = module.compute.vms["server-node-1"].network_interface[0].access_config[0].nat_ip
  ttl         = local.cloudflare.ttl
  proxied     = local.cloudflare.proxied

  providers = {
    cloudflare = cloudflare
  }
}
