include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws//.?version=6.5.0"
}

locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_prefix = local.env_vars.locals.project_prefix
  environment    = local.env_vars.locals.environment
  aws_region     = local.env_vars.locals.aws_region
  cidr           = local.env_vars.vpc_cidr
}

inputs = {
  name = "${local.project_prefix}-${local.environment}-vpc"
  cidr = local.cidr
  azs  = ["${local.aws_region}a", "${local.aws_region}b"]

  public_subnets = [
    cidrsubnet(local.cidr, 8, 0),
    cidrsubnet(local.cidr, 8, 1),
  ]
  private_subnets = [
    cidrsubnet(local.cidr, 8, 100),
    cidrsubnet(local.cidr, 8, 101),
  ]
  database_subnets = [
    cidrsubnet(local.cidr, 8, 200),
    cidrsubnet(local.cidr, 8, 201),
  ]

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  enable_nat_gateway = true
  single_nat_gateway = true

  create_elasticache_subnet_group = false
  create_redshift_subnet_group    = false
  create_database_subnet_group    = true

  tags = merge(local.env_vars.locals.tags, {
    "TerragruntPath" = "${get_path_from_repo_root()}"
  })
}
