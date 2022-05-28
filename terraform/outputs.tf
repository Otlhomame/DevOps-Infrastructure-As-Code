#Using output vaqriables to automatically find IP Addresses to verify them
output "dev_ip" {
  value = aws_instance.dev_node.public_ip
}