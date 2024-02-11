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

resource "aws_subnet" "jimi_subnet_1" {
  vpc_id            = aws_vpc.jimi_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.availability_zone_1

  tags = {
    Name = "jimiSubnet1"
  }
}


resource "aws_subnet" "jimi_subnet_2" {
  vpc_id            = aws_vpc.jimi_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.availability_zone_2

  tags = {
    Name = "jimiSubnet2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "jimi_igw" {
  vpc_id = aws_vpc.jimi_vpc.id

  tags = {
    Name = "jimiIGW"
  }
}
