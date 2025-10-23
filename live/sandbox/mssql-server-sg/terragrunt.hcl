include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "tfr:///terraform-aws-modules/security-group/aws//.?version=5.3.1"
}

locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_prefix = local.env_vars.locals.project_prefix
  environment    = local.env_vars.locals.environment

  name = "${local.project_prefix}-${local.environment}-db-sg"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  name        = local.name
  description = "Security group for MSSQL server"
  vpc_id      = dependency.vpc.outputs.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 1433
      to_port     = 1433
      protocol    = "tcp"
      description = "SqlServer access from within VPC"
      cidr_blocks = dependency.vpc.outputs.vpc_cidr_block
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "tcp"
      cidr_blocks = dependency.vpc.outputs.vpc_cidr_block
    },
  ]

  tags = local.tags
}
