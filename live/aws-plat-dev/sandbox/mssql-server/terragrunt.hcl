include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws//.?version=6.13.1"
}

locals {
  env_vars       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_prefix = local.env_vars.locals.project_prefix
  environment    = local.env_vars.locals.environment

  name = "${local.project_prefix}-${local.environment}-db"
}

dependency "sg" {
  config_path = "../mssql-server-sg/"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  identifier = local.name

  engine               = "sqlserver-ex"
  engine_version       = "15.00"
  family               = "sqlserver-ex-15.0"
  major_engine_version = "15.00"
  instance_class       = "db.t3.large"

  allocated_storage     = 20
  max_allocated_storage = 60
  storage_type          = "gp3"

  // Not available in the express edition of mssql
  storage_encrypted = false

  iam_database_authentication_enabled = true

  db_name  = "song88_${local.environment}"
  username = "${local.environment}_admin"
  port     = 1433

  multi_az               = false
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group
  vpc_security_group_ids = [dependency.sg.outputs.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["error"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60

  options                   = []
  create_db_parameter_group = false
  license_model             = "license-included"
  timezone                  = "GMT Standard Time"
  character_set_name        = "Latin1_General_CI_AS"

  tags = merge(local.env_vars.locals.tags, {
    "TGPath" = "${get_path_from_repo_root()}"
  })
}
