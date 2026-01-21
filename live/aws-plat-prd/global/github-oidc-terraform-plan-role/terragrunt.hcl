
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr://registry.terraform.io/unfunco/oidc-github/aws//?version=1.8.0"
}

inputs = {
  enabled                 = true
  attach_admin_policy     = false
  attach_read_only_policy = true
  create_oidc_provider    = false
  force_detach_policies   = false
  iam_role_name           = "github-oidc-terraform-plan-role"
  github_thumbprint       = "6938fd4d98bab03faadb97b34396831e3780aea1"
  max_session_duration    = "3600"

  iam_role_inline_policies = {
    PushECRDockerImages = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Effect": "Allow",
          "Action": [
            "eks:DescribeCluster",
            "eks:DescribeNodegroup",
            "eks:DescribeAddon*",
            "eks:ListAddons"
          ],
          "Resource": "*"
      }
  ]
}
POLICY
  }

  github_repositories = [
    "FlyingCockatoo/infrastructure:*",
  ]
}
