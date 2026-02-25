include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/key-pair/aws//?version=2.1.1"
}

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment
}

inputs = {
  key_name = "${local.environment}-mongodb"

  create_private_key = false

  // The private key is stored as 'MongoDB Stage SSH Key' in 1Password.
  private_key_algorithm = "ED25519"
  public_key            = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILGF/PC4ryjfUoFeE0op1Qe4SFEH7gnHPV+5ET1jFt50"

  tags = merge(local.env_vars.locals.tags, {
    "TGPath" = "${get_path_from_repo_root()}"
  })
}
