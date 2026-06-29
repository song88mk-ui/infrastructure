include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/sso-account-assignments/"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  plat_stage   = "172065883315"
  plat_prod    = "525375333516"
  core_public  = "458329143434"
  core_network = "445875720494"
  root         = "460167718646"
}

dependency "permission_sets" {
  config_path = "../sso-permission-sets/"
}

inputs = {
  accounts = [{
    name       = "plat_stage",
    account_id = local.plat_stage
    permission_sets = {
      AdministratorAccess = [
        "devops"
      ]
      Billing = [
        "billing"
      ]
      EKSPowerUserAccess = [
        "developers"
      ]
    }
    }, {
    name       = "plat_prod",
    account_id = local.plat_prod
    permission_sets = {
      AdministratorAccess = [
        "devops"
      ]
      Billing = [
        "billing"
      ]
    }
    }, {
    name       = "core_public",
    account_id = local.core_public
    permission_sets = {
      AdministratorAccess = [
        "devops"
      ]
      Billing = [
        "billing"
      ]
    }
    }, {
    name       = "core_network",
    account_id = local.core_network,
    permission_sets = {
      AdministratorAccess = [
        "devops"
      ]
      Billing = [
        "billing"
      ]
    }
    }, {
    name       = "root",
    account_id = local.root,
    permission_sets = {
      AdministratorAccess = [
        "devops"
      ]
      Billing = [
        "billing"
      ]
    }
  }]
}
