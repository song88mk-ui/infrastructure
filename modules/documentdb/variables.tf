variable "name" {
  type        = string
  description = "The name of the cluster"
}

variable "environment" {
  type        = string
  description = "The name of the environment"
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign to all the resources"
}

variable "master_password_ssm_path" {
  type        = string
  description = "The SSM path that the master password is saved"
}

variable "egress_from_port" {
  type        = number
  default     = 0
  description = "[from_port]DocumentDB initial port range for egress (e.g. `0`)"
}

variable "egress_to_port" {
  type        = number
  default     = 0
  description = "[to_port]DocumentDB initial port range for egress (e.g. `65535`)"
}

variable "egress_protocol" {
  type        = string
  default     = "-1"
  description = "DocumentDB protocol for egress (e.g. `-1`, `tcp`)"
}

variable "allowed_egress_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of CIDR blocks to be allowed to send traffic outside of the DocumentDB cluster"
}

variable "allowed_security_groups" {
  type        = list(string)
  default     = []
  description = "List of existing Security Groups to be allowed to connect to the DocumentDB cluster"
}

variable "allow_ingress_from_self" {
  type        = bool
  default     = false
  description = "Adds the Document DB security group itself as a source for ingress rules. Useful when this security group will be shared with applications."
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "List of CIDR blocks to be allowed to connect to the DocumentDB cluster"
}

variable "external_security_group_id_list" {
  type        = list(string)
  default     = []
  description = "List of external security group IDs to attach to the Document DB"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to create the cluster in (e.g. `vpc-a22222ee`)"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of VPC subnet IDs to place DocumentDB instances in"
}

# https://docs.aws.amazon.com/documentdb/latest/developerguide/limits.html#suported-instance-types
variable "instance_class" {
  type        = string
  default     = "db.t3.medium"
  description = "The instance class to use. For more details, see https://docs.aws.amazon.com/documentdb/latest/developerguide/db-instance-classes.html#db-instance-class-specs"
}

variable "cluster_size" {
  type        = number
  default     = 1
  description = "Number of DB instances to create in the cluster"
}

variable "snapshot_identifier" {
  type        = string
  default     = ""
  description = "Specifies whether or not to create this cluster from a snapshot. You can use either the name or ARN when specifying a DB cluster snapshot, or the ARN when specifying a DB snapshot"
}

variable "db_port" {
  type        = number
  default     = 27017
  description = "DocumentDB port"
}

variable "master_username" {
  type        = string
  default     = "mongodb_root"
  description = "(Required unless a snapshot_identifier is provided) Username for the master DB user"
}

variable "manage_master_user_password" {
  type        = bool
  description = "Whether to manage the master user password using AWS Secrets Manager."
  default     = true
}

variable "retention_period" {
  type        = number
  default     = 7
  description = "Number of days to retain backups for"
}

variable "preferred_backup_window" {
  type        = string
  default     = "07:00-09:00"
  description = "Daily time range during which the backups happen"
}

variable "preferred_maintenance_window" {
  type        = string
  default     = "Mon:22:00-Mon:23:00"
  description = "The window to perform maintenance in. Syntax: `ddd:hh24:mi-ddd:hh24:mi`."
}

variable "cluster_parameters" {
  type = list(object({
    apply_method = string
    name         = string
    value        = string
  }))
  default     = []
  description = "List of DB parameters to apply"
}

variable "cluster_family" {
  type        = string
  default     = "docdb8.0"
  description = "The family of the DocumentDB cluster parameter group. For more details, see https://docs.aws.amazon.com/documentdb/latest/developerguide/db-cluster-parameter-group-create.html"
}

variable "engine" {
  type        = string
  default     = "docdb"
  description = "The name of the database engine to be used for this DB cluster. Defaults to `docdb`. Valid values: `docdb`"
}

variable "engine_version" {
  type        = string
  default     = "8.0.0"
  description = "The version number of the database engine to use"
}

variable "storage_encrypted" {
  type        = bool
  description = "Specifies whether the DB cluster is encrypted"
  default     = true
}

variable "storage_type" {
  type        = string
  description = "The storage type to associate with the DB cluster. Valid values: standard, iopt1"
  default     = "standard"

  validation {
    condition     = contains(["standard", "iopt1"], var.storage_type)
    error_message = "Error: storage_type value must be one of two options - 'standard' or 'iopt1'."
  }
}

variable "kms_key_id" {
  type        = string
  description = "The ARN for the KMS encryption key. When specifying `kms_key_id`, `storage_encrypted` needs to be set to `true`"
  default     = ""
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Determines whether a final DB snapshot is created before the DB cluster is deleted"
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "A value that indicates whether the DB cluster has deletion protection enabled"
  default     = true
}

variable "apply_immediately" {
  type        = bool
  description = "Specifies whether any cluster modifications are applied immediately, or during the next maintenance window"
  default     = true
}

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Specifies whether any minor engine upgrades will be applied automatically to the DB instance during the maintenance window or not"
  default     = true
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "List of log types to export to cloudwatch. The following log types are supported: `audit`, `profiler`"
  default     = []
}

variable "enable_performance_insights" {
  type        = bool
  description = "Specifies whether to enable Performance Insights for the DB Instance."
  default     = false
}

variable "ca_cert_identifier" {
  type        = string
  description = "The identifier of the CA certificate for the DB instance"
  default     = null
}

variable "ssm_parameter_enabled" {
  type        = bool
  default     = false
  description = "Whether an SSM parameter store value is created to store the database password."
}

variable "allow_major_version_upgrade" {
  type        = bool
  description = "Specifies whether major version upgrades are allowed. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster#allow_major_version_upgrade"
  default     = false
}
