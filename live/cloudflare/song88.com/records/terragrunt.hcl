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
      name    = "agentapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "agentpush.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "agent.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "api.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "backoffice.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "bc-platformweb.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "boapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "bo.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "casinoapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "ch.song88.com"
      type    = "A"
      content = "13.70.36.220"
      proxied = false
    },
    {
      name    = "kr-platformweb.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "ldclientapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "maintenanceapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "monitor.song88.com"
      type    = "A"
      content = "20.157.213.57"
      proxied = true
    },
    {
      name    = "ofclientapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "pg.song88.com"
      type    = "A"
      content = "13.70.36.220"
      proxied = false
    },
    {
      name    = "platformapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "platformweb.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "preprod2.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-af-platformweb.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-bc-platformweb.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-bgapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-boapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-bo.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-bo-websocketapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-clientapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-clientplatformapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-kr-platformweb.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-ldclientapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-oddinapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-ofclientapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-operatorapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-platformapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-platformweb.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-qtechapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-rc-api.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-sportsbookapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-vs.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-walletapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-websocketapi2.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "preprod-websocketapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "prod-backofficeapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "prod-clientapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "prod-clientplatformapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "prod-oddinapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "prod-operatorapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "prod-platformapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "prod-qtechapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "prod-walletapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "prod-websocketapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "rc-api.song88.com"
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
      name    = "sportsbookapi.song88.com"
      type    = "A"
      content = "20.157.219.6"
      proxied = true
    },
    {
      name    = "staging-adminapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "staging-admin.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "staging-agentapi.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "staging-agentpush.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "staging-agent.song88.com"
      type    = "A"
      content = "20.47.126.27"
      proxied = true
    },
    {
      name    = "tableau.song88.com"
      type    = "A"
      content = "13.70.36.220"
      proxied = false
    },
    {
      name    = "vs.song88.com"
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
      name    = "29566739.song88.com"
      type    = "CNAME"
      content = "sendgrid.net"
      proxied = false
    },
    {
      name    = "apl.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "assets.song88.com"
      type    = "CNAME"
      content = "assets-song88.azureedge.net"
      proxied = false
    },
    {
      name    = "bec.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "_domainconnect.song88.com"
      type    = "CNAME"
      content = "_domainconnect.gd.domaincontrol.com"
      proxied = true
    },
    {
      name    = "em3067.song88.com"
      type    = "CNAME"
      content = "u29566739.wl240.sendgrid.net"
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
      name    = "url9259.song88.com"
      type    = "CNAME"
      content = "sendgrid.net"
      proxied = false
    },
    {
      name    = "w88.support.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
    },
    {
      name    = "ws.song88.com"
      type    = "CNAME"
      content = "song88.service.signalr.net"
      proxied = true
    },
    {
      name    = "zda888cb26b7b4010cab139a9c7d2993b4.song88.com"
      type    = "CNAME"
      content = "desk.cs.zohohost.com"
      proxied = false
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
      name    = "_acme-challenge.tableau.song88.com"
      type    = "TXT"
      content = "r1gOWjjSiSvhMPnlqHGQunuRFxbixiOObX6E-iu6j9s"
      proxied = false
    }
  ]
}
