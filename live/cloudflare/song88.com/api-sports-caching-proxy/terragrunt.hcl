include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules//cloudflare/worker"
}

locals {
  env_vars         = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  api_token        = run_cmd("--terragrunt-quiet", "aws", "ssm", "get-parameter", "--name", "/cloudflare/terraform-token", "--region", "ap-southeast-1", "--with-decryption", "--query", "Parameter.Value", "--output", "text")
  api_sports_token = run_cmd("--terragrunt-quiet", "aws", "ssm", "get-parameter", "--name", "/cloudflare/api-sports/token", "--region", "ap-south-1", "--with-decryption", "--query", "Parameter.Value", "--output", "text")
}

inputs = {
  api_token  = local.api_token
  account_id = local.account_vars.locals.account_id

  worker_name  = "sports-results-proxy"
  content_file = "${get_terragrunt_dir()}/worker.js"
  main_module  = "worker.js"

  compatibility_date  = "2026-07-01"
  workers_dev_enabled = false

  bindings = [
    {
      name = "ENVIRONMENT"
      type = "plain_text"
      text = "production"
    },
    {
      name = "APISPORTS_KEY"
      type = "secret_text"
      text = local.api_sports_token
    },
  ]

  routes = [
    {
      pattern = "song88.com/api/sports/*"
      zone_id = local.env_vars.locals.zone_id
    },
  ]
}
