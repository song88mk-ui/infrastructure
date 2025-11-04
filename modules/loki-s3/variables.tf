variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "default_route_table_id" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "iam_role_name" {
  type = string
}

variable "iam_policy_name" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "service_accounts" {
  type    = list(string)
  default = []
}

variable "enable_bucket_versioning" {
  type    = bool
  default = false
}
