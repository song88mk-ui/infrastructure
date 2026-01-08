# Data source to get the SSO instance
data "aws_ssoadmin_instances" "main" {}

# Data sources to look up permission sets by name
data "aws_ssoadmin_permission_set" "this" {
  for_each = toset(
    flatten([
      for account in var.accounts : keys(account.permission_sets)
    ])
  )

  instance_arn = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  name         = each.value
}

# Data sources to look up groups by name
data "aws_identitystore_group" "this" {
  for_each = toset(
    flatten([
      for account in var.accounts : flatten([
        for permission_set, groups in account.permission_sets : groups
      ])
    ])
  )

  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value
    }
  }
}

locals {
  account_assignments = flatten([
    for account in var.accounts : [
      for permission_set_name, groups in account.permission_sets : [
        for group in groups : {
          account_id     = account.account_id
          account_name   = account.name
          permission_set = permission_set_name
          group          = group
          assignment_key = "${account.name}-${permission_set_name}-${group}"
        }
      ]
    ]
  ])

  assignments_map = {
    for assignment in local.account_assignments :
    assignment.assignment_key => assignment
  }
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.assignments_map

  instance_arn       = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  permission_set_arn = data.aws_ssoadmin_permission_set.this[each.value.permission_set].arn

  principal_id   = data.aws_identitystore_group.this[each.value.group].group_id
  principal_type = "GROUP"

  target_id   = each.value.account_id
  target_type = "AWS_ACCOUNT"
}
