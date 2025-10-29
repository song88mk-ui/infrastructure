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
  name            = "eks-cluster-creator-role"
  description     = "Role to be assumed by users that will be creating EKS clusters"
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
          "arn:aws:*::${get_aws_account_id()}:*/AWSReservedSSO_AdministratorAccess*",
        ]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    EKSClusterCreation = {
      actions = [
        "eks:*",
        "iam:*",
        "cloudformation:*",
        "ec2:*",
        "autoscaling:*",
        "ssm:*",
        "kms:*",
        "sts:GetCallerIdentity",
      ]
      resources = ["*"]
    }
  }
}

