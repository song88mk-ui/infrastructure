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
    "bg-rabbitmq-api"       = {}
    "bg-receiver-service"   = {}
    "bg-feed-receiver-api"  = {}
    "bg-engine-sportsbook"  = {}
    "bg-feedlogger-service" = {}
    "bg-heartbeat-listener" = {}
    "bg-job-cleanup"        = {}
    # oddsengine-2
    "oev2-adapter-service"     = {}
    "oev2-sportsbook-service"  = {}
    "oev2-websocket-service"   = {}
    "oev2-uof-client"          = {}
    "oev2-job-keepalive"       = {}
    "oev2-job-settlement"      = {}
    "oev2-job-cleanup"         = {}
    "oev2-job-livestream"      = {}
    "oev2-job-lookup"          = {}
    "oev2-translation-job"     = {}
    "oev2-translation-service" = {}
    # platform apps (old platform)
    "platform-platform-api"             = {}
    "platform-betforwarder-service"     = {}
    "platform-betinfo-service"          = {}
    "platform-betstatus-service"        = {}
    "platform-betting-api"              = {}
    "platform-cachesync-service"        = {}
    "platform-provider-service"         = {}
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
    "platform-auth-api"                 = {}
    # web layouts
    "platform-web-mockup" = {}
    "platform-web-assets" = {}
    "platform-web"        = {}
    "platform-song88"     = {}
    "platform-web-af"     = {}
    # web utils
    "platform-webprops-api" = {}
    # client checklist
    "client-checklist-api" = {}
    "client-checklist-web" = {}
    # backoffice
    "backoffice-bo-api"            = {}
    "backoffice-bo-web"            = {}
    "backoffice-utility-service"   = {}
    "backoffice-websocket-service" = {}
    "backoffice-config-service"    = {}
    "backoffice-websocket-api"     = {}
    # internal documentation
    "corp-apps-internal-docs" = {}
    # API-SPORTS
    "api-sports-caching-proxy" = {}
  }
}

