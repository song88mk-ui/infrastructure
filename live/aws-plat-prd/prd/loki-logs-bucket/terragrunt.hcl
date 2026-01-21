include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/loki-s3"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  environment    = local.env_vars.locals.environment
  project_prefix = local.env_vars.locals.project_prefix
  aws_region     = local.env_vars.locals.aws_region
}

dependency "vpc" {
  config_path = "../vpc/"
}

dependency "eks" {
  config_path = "../eks/"
}

inputs = {
  aws_region = local.aws_region

  bucket_name     = "${local.project_prefix}-${local.environment}-loki-logs"
  iam_role_name   = "${local.project_prefix}-${local.environment}-loki-logs"
  iam_policy_name = "${local.project_prefix}-${local.environment}-loki-logs"

  eks_cluster_name = dependency.eks.outputs.cluster_name

  vpc_id                 = dependency.vpc.outputs.vpc_id
  default_route_table_id = dependency.vpc.outputs.default_route_table_id
}
