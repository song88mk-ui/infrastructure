include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/documentdb"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  environment    = local.env_vars.locals.environment
  project_prefix = local.env_vars.locals.project_prefix
  aws_region     = local.env_vars.locals.aws_region

  instance_class = local.env_vars.locals.documentdb_instance_class
}

dependency "vpc" {
  config_path = "../vpc/"
}

inputs = {
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets

  name                     = "mongodb"
  environment              = local.environment
  master_password_ssm_path = "/${local.environment}/mongodb/master_password"

  allowed_cidr_blocks = [local.env_vars.locals.vpc_cidr]
}

