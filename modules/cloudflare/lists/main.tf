
resource "cloudflare_list" "list" {
  for_each    = var.lists
  account_id  = var.account_id
  name        = each.key
  kind        = each.value.kind
  description = each.value.description
  items       = each.value.items
}
