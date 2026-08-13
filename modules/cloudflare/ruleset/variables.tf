variable "api_token" {
  description = "The Cloudflare API Token"
  type        = string
}

variable "description" {
  description = "Brief summary of the ruleset and its intended use"
  type        = string
  default     = null
}

variable "kind" {
  description = "Cloudflare ruleset kinds include: custom (user-defined), entry point (serves as the entrypoint for phases - can be set to 'root' at the account level and 'zone' at the zone level), and managed (preconfigured by Cloudflare)."
  type        = string

  validation {
    condition     = can(regex("^(custom|managed|root|zone)$", var.kind))
    error_message = "Invalid kind value. Kind must be one of: custom, managed, root, zone."
  }
}

variable "phase" {
  description = "Phase refers to a stage in the process of handling a request/response lifecycle. Refer doc https://developers.cloudflare.com/ruleset-engine/reference/phases-list/"
  type        = string

  validation {
    condition     = can(regex("^(ddos_l4|ddos_l7|http_config_settings|http_custom_errors|http_log_custom_fields|http_ratelimit|http_request_cache_settings|http_request_dynamic_redirect|http_request_firewall_custom|http_request_firewall_managed|http_request_late_transform|http_request_origin|http_request_redirect|http_request_sanitize|http_request_sbfm|http_request_transform|http_response_compression|http_response_firewall_managed|http_response_headers_transform|magic_transit)$", var.phase))
    error_message = "Invalid phase value. Phase must be one of: ddos_l4, ddos_l7, http_config_settings, http_custom_errors, http_log_custom_fields, http_ratelimit, http_request_cache_settings, http_request_dynamic_redirect, http_request_firewall_custom, http_request_firewall_managed, http_request_late_transform, http_request_origin, http_request_redirect, http_request_sanitize, http_request_sbfm, http_request_transform, http_response_compression, http_response_firewall_managed, http_response_headers_transform, magic_transit."
  }
}

variable "rules" {
  description = "List of rules to apply to the ruleset"
  type = list(object({
    action      = string
    description = string
    enabled     = bool
    expression  = string
    logging = optional(object({
      enabled = bool
    }))
    action_parameters = optional(object({
      response = optional(object({
        content      = string
        content_type = string
        status_code  = number
      }))
      phases   = optional(list(string))
      products = optional(list(string))
      ruleset  = optional(string)
    }))
  }))
}

variable "ruleset_name" {
  description = "The name of the Cloudflare ruleset"
  type        = string
}

variable "zone_id" {
  description = "The zone associated with this ruleset. One of zone_id or account_id must be present but not both."
  type        = string
}
