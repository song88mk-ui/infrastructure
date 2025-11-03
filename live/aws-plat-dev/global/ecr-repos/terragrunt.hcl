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
    "platform-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-betforwarder-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-betinfo-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-betstatus-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-betting-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-cachesync-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-cancellation-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-cashout-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-cashoutstake-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-client-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-client-topmarket-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-clientplatform-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-clientsportsbook-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-job-ccf" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-job-forexeur" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-job-operator-score" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-job-resettlement" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-operator-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-operator-cashout-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-operator-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-placement-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-rabbitmq-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-settlement-service" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-sportsbook-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-wallet-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-websocket-api" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
    "platform-websocket-client" = {
      devImagePrefix = "main-sha"
      devImageCount  = 50
      prodImageCount  = 70
    }
  }
}

