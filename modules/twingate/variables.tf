variable "api_token" {
  description = "Twingate API Token"
}

variable "network" {
  default     = "song88"
  description = "The network that the resource belongs to"
}

variable "remote_networks" {
  description = "Map of remote networks to create"
  type = map(object({
    name             = string
    location         = optional(string, "OTHER")
    total_connectors = optional(number, 1)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.remote_networks : contains([
        "AWS", "AZURE", "GOOGLE_CLOUD", "ON_PREMISE", "OTHER"
      ], v.location)
    ])
    error_message = "Location must be one of: AWS, AZURE, GOOGLE_CLOUD, ON_PREMISE, OTHER"
  }
}

variable "groups" {
  description = "Map of groups to create"
  type = map(object({
    name               = string
    security_policy_id = optional(string)
    user_ids           = optional(list(string))
  }))
  default = {}
}

variable "resources" {
  description = "Map of resources to create and assign to networks and groups"
  type = map(object({
    name                        = string
    address                     = string
    remote_network_key          = string
    alias                       = optional(string)
    is_active                   = optional(bool, true)
    is_visible                  = optional(bool, true)
    is_browser_shortcut_enabled = optional(bool, false)
    security_policy_id          = optional(string)
    access_groups               = optional(list(string), [])
  }))
  default = {}
}

