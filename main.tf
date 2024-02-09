
provider "aws" {
  region = var.region
}

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

resource "aws_ecs_cluster" "cluster" {
  name = "jimiiot"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}




