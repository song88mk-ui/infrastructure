locals {
  environment    = "cloudflare"
  project_prefix = "cf"
  aws_region     = "ap-southeast-1"
  zone_id        = "0d3ed7f89402fdb08012ac5cf4a07f56"

  tags = {
    Environment   = local.environment
    ProjectPrefix = local.project_prefix
  }
}
