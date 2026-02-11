module "webprops_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.8.2"

  bucket                  = var.bucket_name
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true

  // Fix for https://github.com/terraform-aws-modules/terraform-aws-s3-bucket/issues/223
  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  acl           = "log-delivery-write"
  force_destroy = true

  versioning = {
    enabled = var.enable_bucket_versioning
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = var.tags
}

module "webprops_role" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.2.1"

  name = var.iam_role_name

  association_defaults = {
    namespace       = "platform"
    service_account = "webprops-api-sa"
  }

  additional_policy_arns = {
    WebPropsApiReadWritePolicy = module.webprops_s3_iam_policy.arn
  }

  associations = {
    main = {
      cluster_name = var.eks_cluster_name
    }
  }

  tags = var.tags
}

data "aws_iam_policy_document" "webprops_s3_policy_document" {
  statement {
    sid = "1"

    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]

    resources = [
      module.webprops_bucket.s3_bucket_arn,
      "${module.webprops_bucket.s3_bucket_arn}/*"
    ]
  }
}

module "webprops_s3_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "6.2.3"

  name        = var.iam_policy_name
  path        = "/"
  description = "Policy for WebPropsApi to use S3 as storage backend"

  policy = data.aws_iam_policy_document.webprops_s3_policy_document.json

  tags = var.tags
}
