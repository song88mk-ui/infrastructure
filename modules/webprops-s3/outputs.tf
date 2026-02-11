output "bucket_arn" {
  value = module.webprops_bucket.s3_bucket_arn
}

output "role_arn" {
  value = module.webprops_role.iam_role_arn
}
