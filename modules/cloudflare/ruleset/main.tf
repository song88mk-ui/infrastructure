resource "cloudflare_ruleset" "this" {
  name        = var.ruleset_name
  description = var.description
  zone_id     = var.zone_id
  account_id  = var.account_id
  kind        = var.kind
  phase       = var.phase

  rules = var.rules
}
