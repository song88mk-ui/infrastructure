include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/sso-permission-sets/"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  permission_sets = [
    {
      name             = "AdministratorAccess",
      description      = "Allow full access to the account",
      relay_state      = "",
      session_duration = "PT4H",
      tags             = local.env_vars.locals.tags,
      inline_policy    = "",
      policy_attachments = [
        "arn:aws:iam::aws:policy/AdministratorAccess",
        "arn:aws:iam::aws:policy/IAMSelfManageServiceSpecificCredentials",
      ]
      customer_managed_policy_attachments = []
    },
    {
      name             = "ReadOnlyAccess",
      description      = "Allow read-only access to the account",
      relay_state      = "",
      session_duration = "PT2H",
      tags             = local.env_vars.locals.tags,
      inline_policy    = "",
      policy_attachments = [
        "arn:aws:iam::aws:policy/ReadOnlyAccess",
      ]
      customer_managed_policy_attachments = []
    },
    {
      name             = "Billing",
      description      = "Allow access to billing information of the account",
      relay_state      = "",
      session_duration = "PT2H",
      tags             = local.env_vars.locals.tags,
      inline_policy    = "",
      policy_attachments = [
        "arn:aws:iam::aws:policy/job-function/Billing",
      ]
      customer_managed_policy_attachments = []
    },
    {
      name             = "EKSPowerUserAccess",
      description      = "Allow EKS access to all clusters",
      relay_state      = "https://console.aws.amazon.com/eks",
      session_duration = "PT2H",
      tags             = local.env_vars.locals.tags,
      inline_policy    = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "sts:AssumeRole"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:GetObject",
                "s3:GetObjectAcl",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::song88-dev-webprops",
                "arn:aws:s3:::song88-stg-webprops",
                "arn:aws:s3:::song88-dev-webprops/*",
                "arn:aws:s3:::song88-stg-webprops/*"
            ]
        }
    ]
}
EOF
      policy_attachments = [
        "arn:aws:iam::aws:policy/ReadOnlyAccess",
      ]
      customer_managed_policy_attachments = []
    },
  ]
}
