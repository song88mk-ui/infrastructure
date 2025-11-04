include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws//modules/zones/.?version=4.1.0"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  zones = {
    "${local.env_vars.locals.environment}.song88.com" = {
      comment = "DNS zone for the ${local.env_vars.locals.environment} env"
      tags    = local.env_vars.locals.tags
    }
  }

  tags = merge(local.env_vars.locals.tags, {
    "TGPath" = "${get_path_from_repo_root()}"
  })
}
