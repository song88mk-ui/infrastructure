include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr://registry.terraform.io/unfunco/oidc-github/aws//?version=1.8.0"
}

inputs = {
  enabled                 = true
  attach_admin_policy     = false
  attach_read_only_policy = false
  create_oidc_provider    = true
  force_detach_policies   = false
  iam_role_name           = "github-oidc-ecr-push-role"
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
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr:BatchCheckLayerAvailability",
              "ecr:PutImage",
              "ecr:InitiateLayerUpload",
              "ecr:UploadLayerPart",
              "ecr:CompleteLayerUpload",
              "ecr:ListImages",
              "ecr:DescribeRepositories",
              "ecr:CreateRepository",
              "ecr:DeleteRepository",
              "ecr:DeleteRepositoryPolicy",
              "ecr:SetRepositoryPolicy",
              "ecr:TagResource",
              "ecr:UntagResource",
              "ecr:Get*"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "ecr:DescribeImages",
              "ecr:GetRepositoryPolicy",
              "ecr:ListTagsForResource",
              "sts:GetServiceBearerToken",
              "ecr-public:*"
          ],
          "Resource": "*"
      }
  ]
}
POLICY
  }

  github_repositories = [
    "FlyingCockatoo/bet-genius:*",
    "FlyingCockatoo/oddsengine:*",
    "FlyingCockatoo/platform-final:*",
    "FlyingCockatoo/Auth:*",
    "FlyingCockatoo/odds-engine-2:*",
  ]
}
