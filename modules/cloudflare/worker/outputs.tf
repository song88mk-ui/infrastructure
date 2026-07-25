output "script_name" {
  description = "The deployed Worker script name"
  value       = cloudflare_workers_script.this.script_name
}

output "route_ids" {
  description = "IDs of the attached Worker routes"
  value       = [for r in cloudflare_workers_route.this : r.id]
}
