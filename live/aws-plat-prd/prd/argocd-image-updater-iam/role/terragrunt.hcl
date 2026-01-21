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
  name             = "argocd-image-updater-${local.environment}"
  role_description = "Role to pull images for ArgoCD Image Updater"

  attach_custom_policy = true
  policy_statements = [
    {
      sid = "ECRPullPolicy"
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:ListTagsForResource",
        "ecr:DescribeImageScanFindings"
      ]
      resources = ["*"]
    }
  ]

  association_defaults = {
    namespace       = "argocd"
    service_account = "argocd-image-updater"
  }

  associations = {
    main = {
      cluster_name = dependency.eks.outputs.cluster_name
    }
  }
}
