include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/rabbitmq/"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  environment    = local.env_vars.locals.environment
  project_prefix = local.env_vars.locals.project_prefix
  aws_region     = local.env_vars.locals.aws_region
}

dependency "vpc" {
  config_path = "../vpc/"
}

inputs = {
  name = "main-broker"

  host_instance_type = "mq.m7g.large"

  vpc_id         = dependency.vpc.outputs.vpc_id
  vpc_cidr_block = local.env_vars.locals.vpc_cidr
  subnet_ids     = [dependency.vpc.outputs.private_subnets[0]]
}
