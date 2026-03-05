locals {
  environment    = "cloudflare"
  project_prefix = "cf"
  aws_region     = "ap-southeast-1"

  tags = {
    Environment   = local.environment
    ProjectPrefix = local.project_prefix
  }
}
