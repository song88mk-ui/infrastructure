include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-role?version=6.2.2"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  project_prefix = local.env_vars.locals.project_prefix
  environment    = local.env_vars.locals.environment
  aws_region     = local.env_vars.locals.aws_region
}

inputs = {
  name            = "eks-developer-access-role"
  description     = "Role to be assumed by developers that will be managing the app specific namespace"
  use_name_prefix = false

  trust_policy_permissions = {
    AssumeRole = {
      actions = [
        "sts:AssumeRole",
      ]
      principals = [{
        type        = "AWS"
        identifiers = ["arn:aws:iam::${get_aws_account_id()}:root"],
      }]
      condition = [{
        test     = "StringLike",
        variable = "aws:PrincipalArn",
        values = [
          "arn:aws:*::${get_aws_account_id()}:*/AWSReservedSSO_EKSPowerUserAccess*",
        ]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    EKSViewPolicy = {
      actions = [
        "sts:GetCallerIdentity",
        "eks:ListClusters",
        "eks:DescribeAddonVersions",
        "eks:ListNodegroups",
        "eks:DescribeFargateProfile",
        "eks:ListTagsForResource",
        "eks:ListAddons",
        "eks:DescribeAddon",
        "eks:ListFargateProfiles",
        "eks:DescribeNodegroup",
        "eks:DescribeIdentityProviderConfig",
        "eks:ListUpdates",
        "eks:DescribeUpdate",
        "eks:AccessKubernetesApi",
        "eks:DescribeCluster",
        "eks:ListIdentityProviderConfigs",
      ]
      resources = ["*"]
    }
  }
}

