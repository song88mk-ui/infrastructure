include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/eks-pod-identity/aws//.?version=2.2.1"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  project_prefix = local.env_vars.locals.project_prefix
  environment    = local.env_vars.locals.environment
  aws_region     = local.env_vars.locals.aws_region
  cidr           = local.env_vars.locals.vpc_cidr
}

dependency "eks" {
  config_path = "../../eks"
}

inputs = {
  name = "external-secrets-iam-role-${local.environment}"

  attach_external_secrets_policy        = true
  external_secrets_ssm_parameter_arns   = ["arn:aws:ssm:${local.aws_region}:${get_aws_account_id()}:parameter/${local.environment}/*"]
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${local.aws_region}:${get_aws_account_id()}:secret:${local.environment}/*"]
  external_secrets_create_permission    = true

  association_defaults = {
    namespace       = "external-secrets"
    service_account = "external-secrets-sa"
  }

  associations = {
    main = {
      cluster_name = dependency.eks.outputs.cluster_name
    }
  }
}
