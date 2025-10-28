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
  name             = "aws-load-balancer-controller"
  role_description = "Role to manage dynamically provisioned ALB instances"

  attach_aws_lb_controller_policy = true

  association_defaults = {
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller-sa"
  }

  associations = {
    main = {
      cluster_name = dependency.eks.outputs.cluster_name
    }
  }
}
