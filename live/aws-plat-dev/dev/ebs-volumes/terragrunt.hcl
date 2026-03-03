include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/ebs-volumes"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "mongodb" {
  config_path = "../mongodb-ec2-instance/"
}

dependency "mongodb_02" {
  config_path = "../mongodb-02/"
}

inputs = {
  volumes = {
    "mongodb-data" = {
      instance_id = dependency.mongodb.outputs.id
      device_name = "/dev/sdk"
      throughput  = 500
      size        = "50"
    }

    "mongodb-02-data" = {
      instance_id = dependency.mongodb_02.outputs.id
      device_name = "/dev/sdm"
      throughput  = 500
      size        = "50"
    }
  }

  tags = merge(local.env_vars.locals.tags, {
    "TGPath" = "${get_path_from_repo_root()}"
  })
}
