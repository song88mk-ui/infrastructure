locals {
  environment    = "global"
  project_prefix = "song88"
  aws_region     = "ap-east-1"

  tags = {
    Environment   = local.environment
    ProjectPrefix = local.project_prefix
    map-migrate   = "migR5LCBCJJYH"
  }
}
