output "bucket_arn" {
  value = module.loki_logs_bucket.s3_bucket_arn
}

output "role_arn" {
  value = module.loki_writer_role.iam_role_arn
}
