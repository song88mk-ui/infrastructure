include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws//.?version=6.13.1"
}

locals {
  env_vars             = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  master_user_password = run_cmd("--terragrunt-quiet", "aws", "ssm", "get-parameter", "--name", "/${local.environment}/mssql/master_user_password", "--region", local.aws_region, "--with-decryption", "--query", "Parameter.Value", "--output", "text")

  environment    = local.env_vars.locals.environment
  project_prefix = local.env_vars.locals.project_prefix
  aws_region     = local.env_vars.locals.aws_region
}

dependency "vpc" {
  config_path = "../vpc/"
}

dependency "sg" {
  config_path = "../mssql-server-sg/"

  mock_outputs = {
    sg_output = "mock-sg-output"
  }
}

inputs = {
  identifier = "${local.environment}-${local.project_prefix}-mssql-server"

  engine               = "sqlserver-se"
  engine_version       = "15.00"
  family               = "sqlserver-se-15.0"
  major_engine_version = "15.00"
  instance_class       = "db.m5.xlarge"

  allocated_storage     = 20
  max_allocated_storage = 80

  storage_encrypted = true
  storage_type      = "gp3"

  username = "admin"
  password = local.master_user_password

  manage_master_user_password = false
  port                        = 1433

  multi_az               = false
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group
  vpc_security_group_ids = [dependency.sg.outputs.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["error"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 1
  skip_final_snapshot     = false
  deletion_protection     = true

  license_model      = "license-included"
  timezone           = "GMT Standard Time"
  character_set_name = "Latin1_General_CI_AS"

  tags = merge(local.env_vars.locals.tags, {
    "TGPath" = "${get_path_from_repo_root()}"
  })
}
