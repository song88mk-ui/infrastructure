terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

variable "api_token" {
  description = "The Cloudflare API token"
  type        = string
}

variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "records" {
  description = "List of DNS records to create"
  type        = list(any)
  default     = []
}

resource "cloudflare_dns_record" "this" {
  for_each = { for idx, record in var.records : format("%s-%s-%s", record.type, record.name, record.content) => record }

  zone_id  = var.zone_id
  name     = each.value.name
  type     = each.value.type
  content  = lookup(each.value, "content", null)
  ttl      = lookup(each.value, "ttl", 1)
  priority = lookup(each.value, "priority", null)
  proxied  = lookup(each.value, "proxied", false)
  comment  = lookup(each.value, "comment", null)
}

output "dns_records" {
  description = "Map of created DNS records"
  value = {
    for idx, record in cloudflare_dns_record.this : idx => {
      id       = record.id
      name     = record.name
      type     = record.type
      content  = record.content
      proxied  = record.proxied
    }
  }
}
