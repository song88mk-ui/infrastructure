remote_state {
  backend = "s3"
  config = {
    encrypt = true
    bucket  = "song88-sandbox-terraform-state"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = "ap-east-1"
  }
  generate = {
    path      = "base.tf"
    if_exists = "overwrite"
  }
}

generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "ap-east-1"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["418541840646"]
}

${file(find_in_parent_folders("providers.hcl"))}
EOF
}

terraform {
  extra_arguments "bucket" {
    commands = "${get_terraform_commands_that_need_vars()}"
  }
}
