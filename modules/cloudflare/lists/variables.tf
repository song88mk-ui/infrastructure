variable "api_token" {
  description = "The Cloudflare API token"
  type        = string
}

variable "account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "lists" {
  default = null
  type = map(object({
    kind        = optional(string)
    description = string
    items = list(object({
      ip = optional(string)
      redirect = optional(object({
        source_url            = optional(string)
        target_url            = optional(string)
        include_subdomains    = optional(string)
        subpath_matching      = optional(string)
        status_code           = optional(number)
        preserve_query_string = optional(string)
        preserve_path_suffix  = optional(string)
      }))
      comment = optional(string)
    }))
  }))
  description = "A list of objects containing the list definitions"
}
