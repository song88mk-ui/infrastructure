
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

dependency "zone" {
  config_path = "../../zone/"
}

inputs = {
  name             = "external-dns-role-${local.environment}"
  role_description = "Role to manage dynamically provisioned DNS records"

  attach_aws_ebs_csi_policy = true

  association_defaults = {
    namespace       = "kube-system"
    service_account = "external-dns-aws-sa"
  }

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [dependency.zone.outputs.route53_zone_zone_arn["${local.environment}.song88.com"]]

  associations = {
    main = {
      cluster_name = dependency.eks.outputs.cluster_name
    }
  }
}
