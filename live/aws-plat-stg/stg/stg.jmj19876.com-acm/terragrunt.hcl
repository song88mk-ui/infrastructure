include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/acm/aws//.?version=2.2.0"
}

locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_prefix = local.env_vars.locals.project_prefix
  environment    = local.env_vars.locals.environment
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  domain_name = "*.${local.environment}.jmj19876.com"
  subject_alternative_names = [
    "${local.environment}.jmj19876.com",
  ]

  validate_certificate = false

  tags = merge(local.env_vars.locals.tags, {
    "TGPath" = "${get_path_from_repo_root()}"
  })
}
