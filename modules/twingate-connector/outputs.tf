output "connector_ip" {
  value = aws_eip.this.public_ip
}
