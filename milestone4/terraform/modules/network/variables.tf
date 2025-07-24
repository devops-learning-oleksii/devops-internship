variable "region" {
  type = string
}
variable "public_tcp_ports" {
  type = list(number)
}
variable "public_udp_ports" {
  type    = list(number)
  default = []
}
variable "private_tcp_ports" {
  type = list(number)
}
variable "private_udp_ports" {
  type    = list(number)
  default = []
}
