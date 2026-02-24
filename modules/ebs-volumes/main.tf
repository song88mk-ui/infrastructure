variable "volumes" {
  type = map(any)
}
variable "tags" {
  type = map(string)
}

data "aws_instance" "this" {
  for_each = var.volumes

  instance_id = each.value.instance_id
}

resource "aws_volume_attachment" "this" {
  for_each = var.volumes

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = each.value.instance_id
}

resource "aws_ebs_volume" "this" {
  for_each = var.volumes

  availability_zone = data.aws_instance.this[each.key].availability_zone
  size              = each.value.size
  encrypted         = true
  throughput        = lookup(each.value, "throughput", null)
  type              = "gp3"

  tags = merge(var.tags, { "Name" = each.key })
}
