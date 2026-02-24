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

  // The private key is stored as 'MongoDB PROD SSH Key' in 1Password.
  private_key_algorithm = "ED25519"
  public_key            = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHJcfVLINZoD7w8Nwq12BkYOJDNrLr9RTIiRjP5V26wU"

  tags = merge(local.env_vars.locals.tags, {
    "TGPath" = "${get_path_from_repo_root()}"
  })
}
