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
  api_token  = local.api_token
  zone_id    = local.env_vars.locals.zone_id
  account_id = null

  ruleset_name = "default"
  kind         = "zone"
  phase        = "http_request_firewall_custom"

  rules = [{
    action      = "skip"
    description = "grafana-unrestricted"
    enabled     = true
    expression  = "(http.host wildcard \"grafana.*.song88.com\")"
    logging = {
      enabled = true
    }
    action_parameters = {
      phases   = ["http_request_firewall_managed"]
      products = ["uaBlock", "bic", "securityLevel"]
      ruleset  = "current"
    }
    }, {
    action      = "skip"
    description = "testing"
    enabled     = true
    expression  = "(http.user_agent contains \"webtau\") or (http.user_agent contains \"curl\")"
    action_parameters = {
      phases   = ["http_ratelimit", "http_request_firewall_managed", "http_request_sbfm"]
      products = ["uaBlock", "bic", "hot", "securityLevel", "rateLimit", "waf", "zoneLockdown"]
      ruleset  = "current"
    }
    logging = {
      enabled = true
    }
    }, {
    action      = "block"
    description = "block geoip country restrictions"
    enabled     = true
    expression  = "(ip.geoip.country in {\"SG\" \"US\"})"
    }, {
    action      = "block"
    description = "block unlisted ips for clientapi affiliates"
    enabled     = true
    expression  = "(http.host eq \"prod-clientapi.song88.com\" and not any(http.request.headers[\"x-api-key\"][*] contains \"hK3UUgRrTz5rZ5mP\"))"
    action_parameters = {
      response = {
        content      = " "
        content_type = "text/plain",
        status_code  = 403,
      }
    }
    }, {
    action      = "block"
    description = "block unlisted ips for preprod clientplatform api"
    enabled     = true
    expression  = "(http.host eq \"preprod-clientplatformapi.song88.com\" and not ip.src in $pp_clientplatapi)"
  }]
}
