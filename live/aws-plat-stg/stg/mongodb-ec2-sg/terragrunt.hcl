include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/security-group/aws//?version=5.3.1"
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment
}

dependency "vpc" {
  config_path = "../vpc/"
}

inputs = {
  name   = "${local.environment}-mongodb-sg"
  vpc_id = dependency.vpc.outputs.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 27017
      to_port     = 27019
      protocol    = "tcp"
      description = "MongoDB access from within the VPC"
      cidr_blocks = dependency.vpc.outputs.vpc_cidr_block
    },
    {
      from_port   = 9092
      to_port     = 9092
      protocol    = "tcp"
      description = "Node exporter"
      cidr_blocks = dependency.vpc.outputs.vpc_cidr_block
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Allow SSH access"
      cidr_blocks = dependency.vpc.outputs.vpc_cidr_block
    },
  ]

  tags = merge(local.env_vars.locals.tags, {
    "TGPath" = "${get_path_from_repo_root()}"
  })
}
