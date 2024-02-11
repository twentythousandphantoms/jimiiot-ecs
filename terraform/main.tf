provider "aws" {
  region = var.region
}


resource "aws_ecs_cluster" "cluster" {
  name = "jimiiot"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
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

# attach AmazonEC2ContainerRegistryReadOnly
resource "aws_iam_policy_attachment" "ecs_execution_role_policy_attachment" {
  name       = "ecs_execution_role_policy_attachment"
  roles      = [aws_iam_role.ecs_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

