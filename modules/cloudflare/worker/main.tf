resource "cloudflare_workers_script" "this" {
  account_id     = var.account_id
  script_name    = var.worker_name
  main_module    = var.main_module
  content_file   = var.content_file
  content_sha256 = filesha256(var.content_file)

  compatibility_date  = var.compatibility_date
  compatibility_flags = var.compatibility_flags

  # In v5, bindings is a single list attribute rather than repeated blocks.
  bindings = var.bindings
}

resource "cloudflare_workers_route" "this" {
  for_each = { for idx, r in var.routes : idx => r }

  zone_id = each.value.zone_id
  pattern = each.value.pattern
  script  = cloudflare_workers_script.this.script_name
}
