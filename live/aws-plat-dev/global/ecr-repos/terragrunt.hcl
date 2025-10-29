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
    "bg-engine-sportsbook" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-rabbitmq-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-adapter-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-adapter-translation-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-boostedoddscap-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-bookmaker-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-config-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-lookup-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-mapping-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-sportsbook-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-engine-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-websocket-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-job-lookup-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-job-mapping-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-job-settlement-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-job-translation-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-marketactivation-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-translation-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "oe-utility-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
  }
}

