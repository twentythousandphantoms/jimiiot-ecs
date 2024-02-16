resource "aws_ecs_cluster" "cluster" {
  name = "jimiiot"

  # logging
    setting {
        name  = "containerInsights"
        value = "enabled"
    }
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "/ecs/jimiiot-dev"
  retention_in_days = 3 # Optional: Configure log retention policy
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
resource "aws_iam_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  name       = "ecs_execution_role_policy_attachment"
  roles      = [aws_iam_role.ecs_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# attach TransitEncryption for EFS
resource "aws_iam_policy_attachment" "AmazonElasticFileSystemClientFullAccess" {
  name       = "ecs_execution_role_policy_attachment"
  roles      = [aws_iam_role.ecs_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
}

resource "aws_iam_policy" "ecs_logs_policy" {
  name        = "ecs_logs_policy"
  description = "Allow ECS tasks to send logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
        ],
        Resource = "*",
        Effect   = "Allow",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ecs_logs_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_logs_policy.arn
}


# The common EFS volume for logs
resource "aws_efs_file_system" "common_volume" {
  creation_token = "commonVolume"
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
  encrypted = false
  lifecycle_policy {
      transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
      Name = "commonVolume"
  }
}

resource "aws_efs_mount_target" "common_volume" {
  count          = length(var.aws_subnets)
  file_system_id = aws_efs_file_system.common_volume.id
  subnet_id = element(var.aws_subnets, count.index)
  security_groups = [var.aws_security_group_id]
}