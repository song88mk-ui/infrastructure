
locals {
  environment    = "stg"
  project_prefix = "song88"
  aws_region     = "ap-south-1"

  vpc_cidr = "10.49.0.0/16"

  documentdb_instance_class = "db.r5.2xlarge"

  tags = {
    Environment   = local.environment
    ProjectPrefix = local.project_prefix
    map-migrate   = "migR5LCBCJJYH"
  }
}
