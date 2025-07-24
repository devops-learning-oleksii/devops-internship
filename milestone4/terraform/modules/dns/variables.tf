variable "domain_name" {
  type = string
}

variable "names" {
  description = "List of record names (e.g., [\"api\", \"@\", \"monitoring\"])"
  type        = list(string)
}

variable "content" {
  description = "IP address for A records"
  type        = string
}

variable "ttl" {
  type = number
}

variable "proxied" {
  type = bool
}
