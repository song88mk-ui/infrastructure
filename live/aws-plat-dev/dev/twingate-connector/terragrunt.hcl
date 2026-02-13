include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules//twingate-connector/"
}

dependency "vpc" {
  config_path = "../vpc"
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment
}

inputs = {
  instance_name = "twingate-${local.environment}-connector-0"
  aws_region    = local.env_vars.locals.aws_region
  subnet_id     = dependency.vpc.outputs.public_subnets[0]

  tags = {
    Environment = local.environment
    Terraform   = "true"
  }
}
