output "bucket_arn" {
  value = module.tempo_traces_bucket.s3_bucket_arn
}

output "role_arn" {
  value = module.tempo_writer_role.iam_role_arn
}
