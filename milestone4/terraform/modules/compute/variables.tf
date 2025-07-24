variable "instances" {
  description = "List of VMs with subnet assignment"
  type = list(object({
    name         = string
    machine_type = string
    image        = string
    ssh_user     = string
    ssh_pubkey   = string
    count        = optional(number, 1)
    public       = optional(bool, false)
  }))
}
variable "network_id" {
  type = string
}
variable "public_subnet_id" {
  type = string
}
variable "private_subnet_id" {
  type = string
}
variable "zone" {
  type = string
}
