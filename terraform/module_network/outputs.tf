output "aws_subnets" {
  value = aws_subnet.jimi_subnet.*.id
  description = "The IDs of the subnets"
}

output "aws_security_group_id" {
  value = aws_security_group.jimi_common_sg.id
}


output "aws_vpc_id" {
  value = aws_vpc.jimi_vpc.id
}

output "service_discovery_namespace" {
  value = aws_service_discovery_private_dns_namespace.service_discovery_namespace
}