
locals {
  environment    = "sandbox"
  project_prefix = "song88"
  aws_region     = "ap-east-1"

  vpc_cidr = "10.28.0.0/16"

  tags = {
    Environment   = local.environment
    ProjectPrefix = local.project_prefix
  }
}
