include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/sso-identities/"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  groups = [{
    name = "devops"
    }, {
    name = "developers"
    }, {
    name = "billing"
    }, {
    name = "eks-power-users"
  }]

  users = [{
    given_name  = "Jan"
    family_name = "Hansen"
    email       = "jh@song88.com"

    groups = [
      "billing",
      "devops",
    ]
    }, {
    given_name  = "Petter Magnus"
    family_name = "Karlsson"
    email       = "mk@song88.com"

    groups = [
      "billing",
      "devops",
    ]
    }, {
    given_name  = "Aries"
    family_name = "Teanila"
    email       = "ateanila@song88.com"

    groups = [
      "developers",
      "eks-power-users",
    ]
    }, {
    given_name  = "Janseen"
    family_name = "Limsiaco"
    email       = "jlimsiaco@song88.com"

    groups = [
      "developers",
      "eks-power-users",
    ]
    }, {
    given_name  = "John"
    family_name = "Schwarts Lineses"
    email       = "jlineses@song88.com"

    groups = [
      "developers",
      "eks-power-users",
    ]
    }, {
    given_name  = "Michel"
    family_name = "Morizot"
    email       = "michel@song88.com"

    groups = [
      "devops",
      "eks-power-users",
    ]
    }, {
    given_name  = "Alexei"
    family_name = "Davidenko"
    email       = "adavidenko@song88.com"

    groups = [
      "developers",
      "eks-power-users",
    ]
    }, {
    given_name  = "Janina"
    family_name = "Mencero"
    email       = "jmencero@song88.com"

    groups = [
      "developers",
      "eks-power-users",
    ]
    }, {
    given_name  = "Elmer"
    family_name = "Rivera"
    email       = "erivera@song88.com"

    groups = [
      "developers",
      "devops",
      "eks-power-users",
    ]
    }, {
    given_name  = "Konstantinos"
    family_name = "Sideris"
    email       = "ksideris@song88.com"

    groups = [
      "devops",
      "developers",
      "eks-power-users",
    ]
    }, {
    given_name  = "Shaina Mae"
    family_name = "Hechanova"
    email       = "shechanova@song88.com"

    groups = [
      "developers",
      "eks-power-users",
    ]
    }, {
    given_name  = "Aldrin"
    family_name = "Delarea"
    email       = "adelarea@song88.com"

    groups = [
      "developers",
      "eks-power-users",
    ]
    }
  ]
}
