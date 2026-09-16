include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws//.?version=21.6.1"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  project_prefix = local.env_vars.locals.project_prefix
  environment    = local.env_vars.locals.environment
  aws_region     = local.env_vars.locals.aws_region
  cidr           = local.env_vars.locals.vpc_cidr
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "cluster_creator_role" {
  config_path = "../../global/eks-cluster-creator-role/"
}

dependency "developers_role" {
  config_path = "../../global/eks-developer-role/"
}

inputs = {
  name               = "${local.project_prefix}-${local.environment}-cluster"
  kubernetes_version = "1.34"
  region             = local.aws_region

  endpoint_public_access                   = true
  endpoint_public_access_cidrs             = ["0.0.0.0/0"]
  enable_cluster_creator_admin_permissions = true

  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets

  cloudwatch_log_group_retention_in_days = 3
  cloudwatch_log_group_tags              = local.env_vars.locals.tags

  cluster_tags = local.env_vars.locals.tags

  // We use separate autoscaling group per AZ so we can scale independently.
  eks_managed_node_groups = {
    for az, subnet_id in dependency.vpc.outputs.private_subnets : "ng-${az}" => {
      instance_types = ["t3a.xlarge"]
      subnet_ids     = [subnet_id]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size = 3
      max_size = 8

      # This value is ignored after the initial creation
      # https://github.com/bryantbiggs/eks-desired-size-hack
      desired_size = 3
    }
  }

  enabled_log_types = []

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy         = {}
    aws-ebs-csi-driver = {}
    vpc-cni = {
      before_compute = true
    }
  }

  authentication_mode = "API"

  access_entries = {
    eks_cluster_creator_role = {
      principal_arn = dependency.cluster_creator_role.outputs.arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    developers_role = {
      principal_arn = dependency.developers_role.outputs.arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = {
            type = "namespace"
            namespaces = [
              "bet-genius-apps",
              "betgenius",
              "data",
              "oddsengine",
              "oesr",
              "platform",
              "platformsr",
            ]
          }
        }
      }
    }
  }

  tags = merge(local.env_vars.locals.tags, {
    "TerragruntPath" = "${get_path_from_repo_root()}"
  })
}
