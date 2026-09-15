include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  api_token    = run_cmd("--terragrunt-quiet", "aws", "ssm", "get-parameter", "--name", "/cloudflare/terraform-token", "--region", "ap-southeast-1", "--with-decryption", "--query", "Parameter.Value", "--output", "text")
}

terraform {
  source = "../../../../modules/cloudflare/lists"
}

inputs = {
  api_token  = local.api_token
  account_id = local.account_vars.locals.account_id

  lists = {
    "ip_aws_nat_gws" = {
      name        = "ip_aws_nat_gws",
      description = "IP addresses from Twingate and Network Gateways"
      kind        = "ip"

      items = [{
        ip      = "13.203.244.234"
        comment = "Network Gateway DEV"
        }, {
        ip      = "13.205.62.43"
        comment = "Network Gateway STG"
        }, {
        ip      = "43.198.129.173"
        comment = "Network Gateway PRD"
        }, {
        ip      = "13.204.106.185"
        comment = "Twingate connector Dev"
        }, {
        ip      = "3.7.178.117"
        comment = "Twingate connector STG"
        }, {
        ip      = "95.40.172.189"
        comment = "Twingate connector PRD"
      }]
    }

    "ip_list_bg_integration_svc" = {
      name        = "ip_list_bg_integration_svc",
      description = "Refs: https://geniussports.atlassian.net/wiki/spaces/BID/pages/34822507/Integration+Service+Interface"
      kind        = "ip"

      items = [{
        ip      = "12.203.244.234"
        comment = "aws-nat-dev"
        }, {
        ip      = "13.205.62.43"
        comment = "aws-nat-stg"
        }, {
        ip      = "43.198.129.173"
        comment = "aws-nat-prd"
        }, {
        ip = "34.240.244.24"
        }, {
        ip = "34.241.220.64"
        }, {
        ip = "34.242.6.161"
        }, {
        ip = "34.242.67.155"
        }, {
        ip = "34.252.158.247"
        }, {
        ip = "52.19.163.53"
        }, {
        ip = "52.213.172.249"
        }, {
        ip = "52.214.86.245"
        }, {
        ip = "54.72.77.116"
        }, {
        ip = "54.76.226.75"
        }, {
        ip = "54.77.177.22"
        }, {
        ip = "99.80.74.200"
      }]
    }

    "pp_clientplatapi" = {
      name        = "pp_clientplatapi",
      description = "Preprod Client Platform API IP List - HK"
      kind        = "ip"

      items = [{
        ip      = "202.164.191.254"
        comment = "FCIOffice2"
        }, {
        ip      = "13.230.149.183"
        comment = "W88"
        }, {
        ip      = "52.69.118.244"
        comment = "W88"
        }, {
        ip      = "54.249.254.33"
        comment = "W88"
        }, {
        ip      = "54.65.9.79"
        comment = "W88"
        }, {
        ip      = "52.195.140.11"
        comment = "W88-Drake/skype/11-21-24"
        }, {
        ip      = "52.196.59.33"
        comment = "W88-Drake/skype/11-21-24"
      }]
    }

    "p_clientplatapi" = {
      name        = "p_clientplatapi",
      description = "Prod Client Platform API IP List - HK"
      kind        = "ip"

      items = [{
        ip      = "103.17.240.93"
        comment = "W88"
        }, {
        ip      = "103.17.240.94"
        comment = "W88"
        }, {
        ip      = "103.89.20.13"
        comment = "W88"
        }, {
        ip      = "103.89.23.10"
        comment = "W88"
        }, {
        ip      = "103.89.23.15"
        comment = "W88"
        }, {
        ip      = "103.89.23.254"
        comment = "W88"
        }, {
        ip      = "116.66.223.220"
        comment = "W88"
        }, {
        ip      = "122.152.166.93"
        comment = "W88"
        }, {
        ip      = "122.152.166.94"
        comment = "W88"
        }, {
        ip      = "124.6.32.166"
        comment = "W88"
        }, {
        ip      = "124.6.32.182"
        comment = "W88"
        }, {
        ip      = "124.6.32.183"
        comment = "W88"
        }, {
        ip      = "124.6.52.124"
        comment = "W88"
        }, {
        ip      = "205.252.18.137"
        comment = "W88"
        }, {
        ip      = "209.9.48.10"
        comment = "W88"
        }, {
        ip      = "209.9.48.254"
        comment = "W88"
        }, {
        ip      = "209.9.48.253"
        comment = "W88"
        }, {
        ip      = "43.251.67.5"
        comment = "W88"
        }, {
        ip      = "52.196.59.33"
        comment = "W88"
        }, {
        ip      = "61.8.34.190"
        comment = "W88"
        }, {
        ip      = "61.8.34.191"
        comment = "W88"
        }, {
        ip      = "63.216.196.124"
        comment = "W88"
        }, {
        ip      = "63.216.196.125"
        comment = "W88"
        }, {
        ip      = "52.196.59.3"
        comment = "W88"
        }, {
        ip      = "35.72.155.141"
        comment = "W88-ip1"
        }, {
        ip      = "35.75.91.152"
        comment = "W88-ip1"
        }, {
        ip      = "13.112.164.198"
        comment = "W88-ip2"
        }, {
        ip      = "202.164.191.250"
        comment = "office-ip1"
        }, {
        ip      = "202.164.191.254"
        comment = "office-ip2"
      }]
    }

    "preprod_qtechapi_allow_list" = {
      name        = "preprod_qtechapi_allow_list",
      description = "Preprod Platform QTech API - IP List"
      kind        = "ip"

      items = [{
        ip      = "202.164.191.254"
        comment = "FCIOffice1"
        }, {
        ip      = "43.250.225.226"
        comment = "FCIOffice1"
        }, {
        ip      = "3.1.243.244"
        comment = "qtech1"
        }, {
        ip      = "52.114.14.71"
        comment = "qtech2"
        }, {
        ip      = "52.114.32.28"
        comment = "qtech3"
        }, {
        ip      = "202.175.253.62"
        comment = "qtech4"
        }, {
        ip      = "52.79.203.127"
        comment = "qtechboth1"
        }, {
        ip      = "52.76.231.168"
        comment = "qtechboth2"
        }, {
        ip      = "52.229.219.142"
        comment = "vm-sapi-1"
      }]
    }

    "prod_qtechapi_allow_list" = {
      name        = "prod_qtechapi_allow_list",
      description = "Production Platform QTech API - IP List"
      kind        = "ip"

      items = [{
        ip      = "43.250.225.226"
        comment = "FCIOffice1"
        }, {
        ip      = "202.164.191.254"
        comment = "FCIOffice2"
        }, {
        ip      = "18.162.217.103"
        comment = "qtech1"
        }, {
        ip      = "18.184.243.189"
        comment = "qtech2"
        }, {
        ip      = "34.241.71.150"
        comment = "qtech3"
        }, {
        ip      = "34.243.156.16"
        comment = "qtech4"
        }, {
        ip      = "52.77.32.26"
        comment = "qtech5"
        }, {
        ip      = "52.79.203.127"
        comment = "qtechboth1"
        }, {
        ip      = "52.76.231.168"
        comment = "qtechboth2"
        }, {
        ip      = "52.229.219.130"
        comment = "vm-api1"
        }, {
        ip      = "52.229.219.131"
        comment = "vm-api2"
        }, {
        ip      = "52.229.219.141"
        comment = "vm-api3"
        }, {
        ip      = "13.70.36.216"
        comment = "vm-api4"
      }]
    }

    "preprod_walletapi_allow_list" = {
      name        = "preprod_walletapi_allow_list",
      description = "Preprod Platform Wallet API - IP List"
      kind        = "ip"

      items = [{
        ip      = "43.250.225.226"
        comment = "FCIOffice1"
        }, {
        ip      = "202.164.191.254"
        comment = "FCIOffice2"
        }, {
        ip      = "172.211.208.51"
        comment = "Gamsnap IP (DEVOPS-228)"
        }, {
        ip      = "20.50.2.77"
        comment = "Gamsnap IP (DEVOPS-228)"
      }]
    }

    "prod_walletapi_allow_list" = {
      name        = "prod_walletapi_allow_list",
      description = "Production Platform Wallet API - IP List"
      kind        = "ip"

      items = [{
        ip      = "43.250.225.226"
        comment = "FCIOffice1"
        }, {
        ip      = "202.164.191.254"
        comment = "FCIOffice2"
      }]
    }
  }
}
