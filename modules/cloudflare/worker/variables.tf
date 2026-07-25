variable "api_token" {
  description = "The Cloudflare API token"
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "worker_name" {
  description = "Name of the Worker script"
  type        = string
}

variable "content_file" {
  description = "Path to the bundled Worker script (e.g. worker.mjs)"
  type        = string
}

variable "main_module" {
  description = "Entrypoint module filename for ES module Workers"
  type        = string
  default     = "worker.mjs"
}

variable "compatibility_date" {
  description = "Cloudflare Workers compatibility date"
  type        = string
  default     = "2025-01-01"
}

variable "compatibility_flags" {
  description = "Compatibility flags for the Worker runtime"
  type        = list(string)
  default     = []
}

# Bindings are a single list in v5. Each entry has a `type` plus type-specific fields.
# Examples:
#   { name = "API_HOST", type = "plain_text", text = "example.com" }
#   { name = "MY_KV",    type = "kv_namespace", namespace_id = "abc123" }
#   { name = "API_KEY",  type = "secret_text", text = var.api_key }
variable "bindings" {
  description = "List of Worker bindings (plain_text, secret_text, kv_namespace, etc.)"
  type        = any
  default     = []
}

variable "routes" {
  description = "List of routes to attach to the Worker"
  type = list(object({
    pattern = string
    zone_id = string
  }))
  default = []
}
