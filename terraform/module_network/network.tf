# VPC creation
resource "aws_vpc" "jimi_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "jimiVPC"
  }
}

# Subnets

resource "aws_subnet" "jimi_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.jimi_vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "jimiSubnet${count.index + 1}"
  }
}


# Security Group
resource "aws_security_group" "jimi_common_sg" {
  name        = "jimi_common_sg"
  description = "Allow inbound traffic for Jimi Kafka"
  vpc_id      = aws_vpc.jimi_vpc.id

#  ingress {
#    description = "NFS Ingress"
#    from_port   = 2049
#    to_port     = 2049
#    protocol    = "tcp"
#    cidr_blocks = aws_subnet.jimi_subnet.*.cidr_block
#  }
#
#  ingress {
#    description = "Kafka Ingress"
#    from_port   = 9092
#    to_port     = 9092
#    protocol    = "tcp"
#    cidr_blocks = aws_subnet.jimi_subnet.*.cidr_block
#  }
#
#  ingress {
#    description = "Zookeeper Ingress"
#    from_port   = 2181
#    to_port     = 2181
#    protocol    = "tcp"
#    cidr_blocks = aws_subnet.jimi_subnet.*.cidr_block
#  }
#  ingress {
#    description = "HTTPS Ingress for VPC Endpoint"
#    from_port   = 443
#    to_port     = 443
#    protocol    = "tcp"
#    cidr_blocks = aws_subnet.jimi_subnet.*.cidr_block
#  }

#  egress {
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    cidr_blocks = ["0.0.0.0/0"]
#  }

  tags = {
    Name      = "jimi_common_sg",
    Component = "Kafka"
  }
}

variable "jimi_ports" {
  type = list
  default = [
    "443", "2049",
    "9092", "2181",
    "27017", "6379",
    "9080", "9081",
    "10088",
    "10066", "10067",
    "21100", "21200",
    "21201", "21220",
    "23010", "23011",
    "31506", "31507",
    "15002", "21122",
    "8881", # (8888) http-flv port of the media server. Type: HTTP. Used by the iothub-media
    "1935", # (1936) RTMP communication port. Type: TCP. Used by the iothub-media
    "10000", # (10002) JT/T1078 live video port. Type: TCP. Used by the iothub-media
    "10001", # (10003) JT/T1078 history video port. Type: TCP. Used by the iothub-media
    "21189", "21188",
    "21210",

  ]
}

resource "aws_vpc_security_group_ingress_rule" "rule" {
  for_each = toset(var.jimi_ports)
  from_port = each.value
  to_port = each.value
  ip_protocol = "tcp"
  cidr_ipv4 = "10.0.0.0/8"
  security_group_id = aws_security_group.jimi_common_sg.id
}

resource "aws_vpc_security_group_egress_rule" "egress_rule" {
  security_group_id = aws_security_group.jimi_common_sg.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

# Internet Gateway
resource "aws_internet_gateway" "jimi_igw" {
  vpc_id = aws_vpc.jimi_vpc.id

  tags = {
    Name = "jimiIGW"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id       = aws_vpc.jimi_vpc.id
  service_name = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids = aws_subnet.jimi_subnet.*.id
  security_group_ids = [aws_security_group.jimi_common_sg.id]

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_docker" {
  vpc_id       = aws_vpc.jimi_vpc.id
  service_name = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids = aws_subnet.jimi_subnet.*.id
  security_group_ids = [aws_security_group.jimi_common_sg.id]

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.jimi_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_vpc.jimi_vpc.main_route_table_id]
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id            = aws_vpc.jimi_vpc.id
  service_name      = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids        = aws_subnet.jimi_subnet.*.id
  security_group_ids = [aws_security_group.jimi_common_sg.id]

  private_dns_enabled = true
}

locals {
  service_discovery_namespace_name = "${var.name}.local"
}
resource "aws_service_discovery_private_dns_namespace" "service_discovery_namespace" {
  name = local.service_discovery_namespace_name
  vpc  = aws_vpc.jimi_vpc.id
}

# Create a route table
resource "aws_route_table" "jimi_route_table" {
  vpc_id = aws_vpc.jimi_vpc.id

  tags = {
    Name = "jimiRouteTable"
  }
}

# Create a route in the route table that directs all traffic to the Internet Gateway
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.jimi_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.jimi_igw.id
}

# Associate the route table with your subnets
resource "aws_route_table_association" "jimi_route_table_association" {
  count          = length(aws_subnet.jimi_subnet)
  subnet_id      = aws_subnet.jimi_subnet[count.index].id
  route_table_id = aws_route_table.jimi_route_table.id
}

#resource "aws_route" "ecr_api_route" {
#  route_table_id             = aws_route_table.jimi_route_table.id
#  destination_prefix_list_id = aws_vpc_endpoint.ecr_api.prefix_list_id
#  vpc_endpoint_id            = aws_vpc_endpoint.ecr_api.id
#}
#
#resource "aws_route" "ecr_docker_route" {
#  route_table_id             = aws_route_table.jimi_route_table.id
#  destination_prefix_list_id = aws_vpc_endpoint.ecr_docker.prefix_list_id
#  vpc_endpoint_id            = aws_vpc_endpoint.ecr_docker.id
#}