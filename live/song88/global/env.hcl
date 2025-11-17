locals {
  environment    = "root"
  project_prefix = "song88"
  aws_region     = "ap-southeast-1"

  tags = {
    Environment   = local.environment
    ProjectPrefix = local.project_prefix
    map-migrate   = "migR5LCBCJJYH"
  }
}
