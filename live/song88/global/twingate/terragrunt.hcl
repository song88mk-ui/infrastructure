include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/twingate/"
}

locals {
  env_vars  = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  api_token = run_cmd("--terragrunt-quiet", "aws", "ssm", "get-parameter", "--name", "/twingate/api-key", "--region", local.env_vars.locals.aws_region, "--with-decryption", "--query", "Parameter.Value", "--output", "text")
}

inputs = {
  api_token = local.api_token

  remote_networks = {
    dev = {
      name     = "Dev"
      location = "AWS"
    }
    stg = {
      name     = "Stage"
      location = "AWS"
    }
    prd = {
      name     = "Production"
      location = "AWS"
    }
  }

  groups = {
    developers = {
      name = "Developers"
    }
    devops = {
      name = "DevOps"
    }
    backoffice = {
      name = "BackOffice"
    }
    noc = {
      name = "NOC"
    }
  }

  resources = {
    prod_mssql = {
      name               = "MSSQL (PROD)"
      address            = "prd-song88-mssql-server.cdqkiuumgexn.ap-east-1.rds.amazonaws.com"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops", "noc"]
    }
    prod_rabbitmq = {
      name               = "RabbitMQ (PROD)"
      address            = "b-bfc99daf-fb92-4742-af20-8bcf6bd1f118.mq.ap-east-1.on.aws"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops"]
    }
    stg_mssql = {
      name               = "MSSQL (STG)"
      address            = "stg-song88-mssql-server.cz8wmg0s28pd.ap-south-1.rds.amazonaws.com"
      remote_network_key = "stg"
      access_groups      = ["developers", "devops", "noc"]
    }
    stg_rabbitmq = {
      name               = "RabbitMQ (STG)"
      address            = "b-e244ede6-0d6a-4c12-be31-90e96fa9126b.mq.ap-south-1.on.aws"
      remote_network_key = "stg"
      access_groups      = ["developers", "devops"]
    }
    stg_mongodb = {
      name               = "MongoDB (STG)"
      address            = "10.49.100.55"
      remote_network_key = "stg"
      access_groups      = ["developers", "devops"]
    }
    stg_endpoints = {
      name               = "Stage Environment"
      address            = "*.stg.song88.com"
      remote_network_key = "stg"
      access_groups      = ["developers", "devops", "backoffice", "noc"]
    }
    dev_mongodb = {
      name               = "MongoDB (DEV)"
      address            = "10.29.100.172"
      remote_network_key = "dev"
      access_groups      = ["developers", "devops"]
    }
    dev_endpoints = {
      name               = "Dev Environment"
      address            = "*.dev.song88.com"
      remote_network_key = "dev"
      access_groups      = ["developers", "devops", "backoffice"]
    }
    prd_endpoints = {
      name               = "Prod Environment"
      address            = "*.prd.song88.com"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops", "backoffice", "noc"]
    }
    dev_network = {
      name               = "Dev Network"
      address            = "10.29.0.0/16"
      remote_network_key = "dev"
      access_groups      = ["developers", "devops"]
    }
    stg_network = {
      name               = "Stage Network"
      address            = "10.49.0.0/16"
      remote_network_key = "stg"
      access_groups      = ["developers", "devops"]
    }
    prd_network = {
      name               = "PROD Network"
      address            = "10.59.0.0/16"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops"]
    }
    prd_mongodb = {
      name               = "MongoDB (PRD)"
      address            = "10.59.100.160"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops"]
    }
    "*.qtplatform.com" = {
      name               = "*.qtplatform.com"
      address            = "*.qtplatform.com"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops", "noc", "backoffice"]
    }
    "khelraja.com" = {
      name               = "khelraja.com"
      address            = "khelraja.com"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops", "noc", "backoffice"]
    }
    "*.khelraja.com" = {
      name               = "*.khelraja.com"
      address            = "*.khelraja.com"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops", "noc", "backoffice"]
    }
    "bo.song88.com" = {
      name               = "bo.song88.com"
      address            = "bo.song88.com"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops", "backoffice", "noc"]
    }
    dev_demosite = {
      name               = "DemoSite-dev"
      address            = "dev.song88.com"
      remote_network_key = "dev"
      access_groups      = ["developers", "devops", "noc"]
    }
    stg_demosite = {
      name               = "DemoSite-stg"
      address            = "stg.song88.com"
      remote_network_key = "stg"
      access_groups      = ["developers", "devops", "noc"]
    }
    prd_demosite = {
      name               = "DemoSite-prd"
      address            = "song88.com"
      remote_network_key = "prd"
      access_groups      = ["developers", "devops", "noc"]
    }
  }
}
