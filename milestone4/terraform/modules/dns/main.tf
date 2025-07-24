terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

data "cloudflare_zone" "domain" {
  name = var.domain_name
}

resource "cloudflare_record" "a" {
  for_each = toset(var.names)
  zone_id  = data.cloudflare_zone.domain.id
  name     = each.value
  content  = var.content
  type     = "A"
  ttl      = var.ttl
  proxied  = var.proxied
}
