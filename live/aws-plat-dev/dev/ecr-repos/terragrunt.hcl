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
    "bg-rabbitmq-api"                   = {}
    "bg-receiver-service"               = {}
    "bg-feed-receiver-api"              = {}
    "bg-engine-sportsbook"              = {}
    "oe-rabbitmq-api"                   = {}
    "oe-adapter-service"                = {}
    "oe-adapter-translation-service"    = {}
    "oe-api"                            = {}
    "oe-boostedoddscap-service"         = {}
    "oe-bookmaker-service"              = {}
    "oe-config-service"                 = {}
    "oe-lookup-service"                 = {}
    "oe-mapping-service"                = {}
    "oe-sportsbook-service"             = {}
    "oe-engine-service"                 = {}
    "oe-websocket-service"              = {}
    "oe-job-lookup-service"             = {}
    "oe-job-mapping-service"            = {}
    "oe-job-settlement-service"         = {}
    "oe-job-translation-service"        = {}
    "oe-marketactivation-service"       = {}
    "oe-translation-service"            = {}
    "oe-utility-service"                = {}
    "platform-api"                      = {}
    "platform-betforwarder-service"     = {}
    "platform-betinfo-service"          = {}
    "platform-betstatus-service"        = {}
    "platform-betting-api"              = {}
    "platform-cachesync-service"        = {}
    "platform-cancellation-service"     = {}
    "platform-cashout-service"          = {}
    "platform-cashoutstake-service"     = {}
    "platform-client-api"               = {}
    "platform-client-topmarket-service" = {}
    "platform-clientplatform-api"       = {}
    "platform-clientsportsbook-api"     = {}
    "platform-job-ccf"                  = {}
    "platform-job-forexeur"             = {}
    "platform-job-operator-score"       = {}
    "platform-job-resettlement"         = {}
    "platform-operator-api"             = {}
    "platform-operator-cashout-service" = {}
    "platform-operator-service"         = {}
    "platform-placement-service"        = {}
    "platform-rabbitmq-api"             = {}
    "platform-settlement-service"       = {}
    "platform-sportsbook-api"           = {}
    "platform-wallet-api"               = {}
    "platform-websocket-api"            = {}
    "platform-websocket-client"         = {}
  }
}

