variable "accounts" {
  description = "List of AWS accounts with their SSO permission set assignments"
  type = list(object({
    name       = string
    account_id = string
    permission_sets = map(list(string))
  }))

  validation {
    condition     = length(var.accounts) > 0
    error_message = "At least one account must be specified."
  }

  validation {
    condition = alltrue([
      for account in var.accounts :
      can(regex("^[0-9]{12}$", account.account_id))
    ])
    error_message = "All account_id values must be 12-digit AWS account IDs."
  }
}
