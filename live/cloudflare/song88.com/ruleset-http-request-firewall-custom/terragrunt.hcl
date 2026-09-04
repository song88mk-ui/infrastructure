include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  api_token    = run_cmd("--terragrunt-quiet", "aws", "ssm", "get-parameter", "--name", "/cloudflare/terraform-token", "--region", "ap-southeast-1", "--with-decryption", "--query", "Parameter.Value", "--output", "text")
  zone_name    = basename(get_terragrunt_dir())
}

terraform {
  source = "../../../../modules/cloudflare//ruleset"
}

inputs = {
  api_token = local.api_token
  zone_id   = local.env_vars.locals.zone_id

  ruleset_name = "default"
  kind         = "zone"
  phase        = "http_request_firewall_custom"

  rules = [
    {
      action      = "block"
      description = "Client API IP Whitelist - prd"
      enabled     = true
      expression  = "(http.host eq \"client-api.song88.com\" and not ip.src in $platform_client_api_whitelist_prd)"
    },
    {
      action      = "block"
      description = "Client API IP Whitelist - stg"
      enabled     = true
      expression  = "(http.host eq \"client-api.stg.song88.com\" and not ip.src in $platform_client_api_whitelist_stg)"
    },
    {
      action      = "skip"
      description = "Allow our own egress IPs (AWS, twingate, etc)"
      enabled     = true
      expression  = "(ip.src in $ip_aws_nat_gws)"
      logging = {
        enabled = false
      }
      action_parameters = {
        phases  = ["http_ratelimit", "http_request_firewall_managed", "http_request_sbfm"]
        ruleset = "current"
      }
    },
    {
      action      = "skip"
      description = "BG-Integration-Whitelist-Skip"
      enabled     = true
      expression  = "(starts_with(http.host, \"bg-feed-receiver-api\") and ip.src in $ip_list_bg_integration_svc)"
      action_parameters = {
        phases   = ["http_ratelimit", "http_request_firewall_managed", "http_request_sbfm"]
        products = ["bic", "zoneLockdown", "uaBlock", "hot", "securityLevel", "rateLimit", "waf"]
        ruleset  = "current"
      }
      logging = {
        enabled = true
      }
    },
    {
      action      = "skip"
      description = "Allow BO access from third parties"
      enabled     = true
      expression  = "(http.host in {\"bo.stg.song88.com\" \"bo.song88.com\" \"metabase.prd.song88.com\" \"metabase.stg.song88.com\"} and ip.src in {85.115.157.176 3.108.12.97 149.174.254.31 84.46.186.198  172.216.211.21 43.225.113.205 167.71.49.107})"
      action_parameters = {
        phases  = ["http_request_firewall_managed", "http_ratelimit"]
        ruleset = "current"
      }
      logging = {
        enabled = true
      }
    },
    {
      action      = "block"
      description = "BG-Integration-Whitelist-Block"
      enabled     = true
      expression  = "(starts_with(http.host, \"bg-feed-receiver-api\") and not ip.src in $ip_list_bg_integration_svc)"
    },
    {
      action      = "block"
      description = "Country Blocking"
      enabled     = true
      expression  = "(ip.geoip.country in {\"SG\" \"US\"})"
    },
    {
      action      = "block"
      description = "Block access to internal services by default"
      enabled     = true
      expression  = "(http.host wildcard r\"*.stg.song88.com\") or (http.host wildcard r\"*.dev.song88.com\") or (http.host wildcard r\"*.prd.song88.com\")"
    }
  ]
}
