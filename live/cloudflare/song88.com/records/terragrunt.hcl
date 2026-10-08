include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  api_token    = run_cmd("--terragrunt-quiet", "aws", "ssm", "get-parameter", "--name", "/cloudflare/terraform-token", "--region", "ap-southeast-1", "--with-decryption", "--query", "Parameter.Value", "--output", "text")
}

terraform {
  source = "../../../../modules/cloudflare/record"
}

inputs = {
  api_token = local.api_token
  zone_id   = local.env_vars.locals.zone_id
  tags      = local.env_vars.locals.tags

  records = [
    {
      name    = "results.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "www.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "10a.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "10c.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "apl.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "bec.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "idn.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "krj.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "maf.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "s1._domainkey.song88.com"
      type    = "CNAME"
      content = "s1.domainkey.u29566739.wl240.sendgrid.net"
      proxied = false
    },
    {
      name    = "s2._domainkey.song88.com"
      type    = "CNAME"
      content = "s2.domainkey.u29566739.wl240.sendgrid.net"
      proxied = false
    },
    {
      name    = "set.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "w88.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "zda888cb26b7b4010cab139a9c7d2993b4.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "_ca0536fa12e0d845514ed49c6e5ff21e.song88.com"
      type    = "CNAME"
      content = "_f1165e4f857c14f2e9da83fc9517b069.jkddzztszm.acm-validations.aws"
      proxied = false
      comment = "ACM DNS validation for *.song88.com (PRD, 525375333516 ap-east-1). Must stay DNS-only."
    },
    {
      name    = "_32c2636d509dc993072eaabb4a71befb.stg.song88.com"
      type    = "CNAME"
      content = "_cd46df2dfe9a8f9bbfb44d1671f0e8dc.jkddzztszm.acm-validations.aws"
      proxied = false
      comment = "ACM DNS validation for *.stg.song88.com (STG, 172065883315 ap-south-1). Must stay DNS-only."
    },
    {
      name     = "song88.com"
      type     = "MX"
      content  = "alt1.aspmx.l.google.com"
      proxied  = false
      priority = 20
    },
    {
      name     = "song88.com"
      type     = "MX"
      content  = "aspmx.l.google.com"
      proxied  = false
      priority = 10
    },
    {
      name     = "song88.com"
      type     = "MX"
      content  = "aspmx3.googlemail.com"
      proxied  = false
      priority = 50
    },
    {
      name     = "song88.com"
      type     = "MX"
      content  = "aspmx2.googlemail.com"
      proxied  = false
      priority = 40
    },
    {
      name     = "song88.com"
      type     = "MX"
      content  = "alt2.aspmx.l.google.com"
      proxied  = false
      priority = 30
    },
    {
      name     = "song88.com"
      type     = "TXT"
      content  = "atlassian-domain-verification=u5iqSTBhzZZINyG2Pl2yTN0jgLGXvp/GvShrfUa8OFFk0wxkLoN7809qTyCTCJOo"
      proxied  = false
      priority = 30
    },
  ]
}
