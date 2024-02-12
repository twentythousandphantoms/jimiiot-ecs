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
  count             = 3
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

  ingress {
    description = "NFS Ingress"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = aws_subnet.jimi_subnet.*.cidr_block
  }

  ingress {
    description = "Kafka Ingress"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = aws_subnet.jimi_subnet.*.cidr_block
  }

  ingress {
    description = "Zookeeper Ingress"
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = aws_subnet.jimi_subnet.*.cidr_block
  }
  ingress {
    description = "HTTPS Ingress for VPC Endpoint"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = aws_subnet.jimi_subnet.*.cidr_block
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "jimi_common_sg",
    Component = "Kafka"
  }
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

  route_table_ids = [aws_vpc.jimi_vpc.main_route_table_id] # Replace with your route table IDs
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
