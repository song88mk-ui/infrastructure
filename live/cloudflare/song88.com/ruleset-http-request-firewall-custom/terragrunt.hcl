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
      description = "Allow all requests to grafana"
      enabled     = true
      expression  = "(http.host wildcard \"grafana.*.song88.com\")"
      logging = {
        enabled = false
      }
      action_parameters = {
        phases   = ["http_request_firewall_managed", "http_ratelimit", "http_request_sbfm"]
        products = ["uaBlock", "bic", "securityLevel", "rateLimit", "zoneLockdown", "hot", "waf"]
        ruleset  = "current"
      }
    },
    {
      action      = "skip"
      description = "Cucumber UA Testing"
      enabled     = true
      expression  = "(http.user_agent contains \"Cucumber\")"
      action_parameters = {
        phases   = ["http_ratelimit", "http_request_firewall_managed", "http_request_sbfm"]
        products = ["uaBlock", "bic", "hot", "securityLevel", "rateLimit", "waf", "zoneLockdown"]
        ruleset  = "current"
      }
      logging = {
        enabled = false
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
      description = "Block Backoffice & Metabase access by default"
      enabled     = true
      expression  = "http.host in {\"bo.song88.com\" \"bo.stg.song88.com\" \"bo.dev.song88.com\" \"metabase.dev.song88.com\" \"metabase.stg.song88.com\" \"metabase.prd.song88.com\" }"
    },
    {
      action      = "block"
      description = "Block ArgoCD & Grafana access by default"
      enabled     = true
      expression  = "http.host in {\"argocd.prd.song88.com\" \"argocd.stg.song88.com\" \"argocd.dev.song88.com\" \"grafana.prd.song88.com\" \"grafana.stg.song88.com\" \"grafana.dev.song88.com\"}"
    }
  ]
}
