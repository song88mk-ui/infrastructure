data "aws_ssm_parameter" "twingate_access_token" {
  name = "/twingate/${var.instance_name}/access-token"
}

data "aws_ssm_parameter" "twingate_refresh_token" {
  name = "/twingate/${var.instance_name}/refresh-token"
}

data "aws_ami" "this" {
  most_recent = true
  name_regex  = "twingate/images/hvm-ssd/twingate-amd64-*"
  owners      = ["617935088040"]

  filter {
    name   = "name"
    values = ["twingate/images/hvm-ssd/twingate-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.2.0"

  name = var.instance_name

  ami           = data.aws_ami.this.image_id
  instance_type = var.instance_type
  ebs_optimized = true
  monitoring    = true
  subnet_id     = var.subnet_id

  user_data_base64 = base64encode(
    templatefile("${path.module}/user-data.yml", {
      access_token  = data.aws_ssm_parameter.twingate_access_token.value
      refresh_token = data.aws_ssm_parameter.twingate_refresh_token.value
    })
  )

  root_block_device = {
    encrypted  = true
    type       = "gp3"
    size       = 8
  }

  tags = var.tags
}

resource "aws_eip" "this" {
  instance = module.ec2_instance.id
  tags = merge(var.tags, {
    "Name" = var.instance_name
  })
}
