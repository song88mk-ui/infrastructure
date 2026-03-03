include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/ec2-instance/aws//.?version=6.2.0"
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment
}

dependency "vpc" {
  config_path = "../vpc/"
}

dependency "sg" {
  config_path = "../mongodb-ec2-sg"
}

dependency "key" {
  config_path = "../mongodb-ssh-key"
}

inputs = {
  name = "${local.environment}-mongodb"

  ami = "ami-0a14f53a6fe4dfcd1" // Ubuntu 24.04

  instance_type = "t3a.small"

  root_block_device = {
    encrypted = true
    type      = "gp3"
    size      = 30
  }

  private_ip = "10.49.100.55"

  enable_volume_tags = false

  subnet_id              = dependency.vpc.outputs.private_subnets[0]
  vpc_security_group_ids = [dependency.sg.outputs.security_group_id]

  key_name = dependency.key.outputs.key_pair_name

  tags = merge(local.env_vars.locals.tags, {
    "TGPath" = "${get_path_from_repo_root()}"
  })
}
