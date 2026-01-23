output "bucket_arn" {
  value = module.bgfeeds_bucket.s3_bucket_arn
}

output "role_arn" {
  value = module.bgfeeds_role.iam_role_arn
}
