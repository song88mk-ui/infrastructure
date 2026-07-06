include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/eks-pod-identity/aws//.?version=2.8.1"
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
  name             = "cluster-autoscaler-${local.environment}"
  role_description = "Role to manage cluster autoscaling"

  attach_cluster_autoscaler_policy = true

  association_defaults = {
    namespace       = "kube-system"
    service_account = "cluster-autoscaler-sa"
  }

  additional_policy_arns = {
    AutoScalingFullAccess = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  }

  associations = {
    main = {
      cluster_name = dependency.eks.outputs.cluster_name
    }
  }
}
