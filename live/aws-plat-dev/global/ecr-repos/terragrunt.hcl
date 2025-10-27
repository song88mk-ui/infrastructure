include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/ecr"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  repositories = {
    "bg-rabbitmq-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 50
    }
    "bg-receiver-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "bg-feed-receiver-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
  }
}

