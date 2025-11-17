variable "groups" {
  description = "List of groups to create in the Identity Store"
  type = list(object({
    name        = string
    description = optional(string)
  }))
  default = []
}

variable "users" {
  description = "List of users to create in the Identity Store"
  type = list(object({
    given_name   = string
    family_name  = string
    email        = string
    email_type   = optional(string)
    groups       = optional(list(string), [])
  }))
  default = []
}

data "aws_ssoadmin_instances" "this" {}

locals {
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  user_group_memberships = flatten([
    for user in var.users : [
      for group in lookup(user, "groups", []) : {
        username   = user.email
        group_name = group
        key        = "${user.email}-${group}"
      }
    ]
  ])
}

resource "aws_identitystore_group" "this" {
  for_each = { for group in var.groups : group.name => group }

  display_name = each.value.name
  description  = lookup(each.value, "description", null)

  identity_store_id = local.identity_store_id
}


resource "aws_identitystore_user" "this" {
  for_each = { for user in var.users : user.email => user }

  identity_store_id = local.identity_store_id
  display_name      = format("%s %s", each.value.given_name, each.value.family_name)
  user_name         = each.value.email

  name {
    family_name = each.value.family_name
    given_name  = each.value.given_name
  }

  emails {
    value   = each.value.email
    primary = true
    type    = "work"
  }
}

resource "aws_identitystore_group_membership" "this" {
  for_each = { for membership in local.user_group_memberships : membership.key => membership }

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.this[each.value.group_name].group_id
  member_id         = aws_identitystore_user.this[each.value.username].user_id

  depends_on = [
    aws_identitystore_group.this,
    aws_identitystore_user.this,
  ]
}
