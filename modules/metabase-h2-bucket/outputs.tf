output "bucket_arn" {
  value = module.metabase_h2_bucket.s3_bucket_arn
}

output "role_arn" {
  value = module.metabase_h2_role.iam_role_arn
}
