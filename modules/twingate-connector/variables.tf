variable "instance_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  default = "t3a.nano"
  type    = string
}

variable "tags" {
  type = map(string)
}

variable "aws_region" {
  type = string
}

