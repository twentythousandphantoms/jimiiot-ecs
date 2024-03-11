resource "aws_efs_file_system" "redis_volume" {
  creation_token = "redisVolume"

  tags = {
    Name = "redisVolume"
  }
}

# mount target
resource "aws_efs_mount_target" "redis_volume" {
  count          = length(var.aws_subnets)
  file_system_id = aws_efs_file_system.redis_volume.id
  subnet_id      = var.aws_subnets[count.index]
  security_groups = [var.aws_security_group_id]
}

locals {
  # extract from var.docker_images_tags
  redis_image_name = "jimi-redis"
  redis_image_tag = "${local.redis_image_name}-${var.docker_images_tags[local.redis_image_name]}"
}

resource "aws_ecs_task_definition" "redis" {
  family                   = "redis-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name         = "redis"
      image        = "${var.aws_ecr_repository_url}:${local.redis_image_tag}"
      cpu          = 256
      memory       = 512
      essential    = true
      portMappings = [
        {
          containerPort = 6379
          hostPort      = 6379
        },
      ]
      # TODO: AWS Secrets Manager
      command = [
        "redis-server",
        "--protected-mode no",
        "--appendonly yes",
        "--requirepass jimi@123",
      ]

      mountPoints = [
        {
          sourceVolume  = "redisVolume"
          containerPath = "/data"
          readOnly      = false
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "redis"
        }
      }
    }
  ])

  volume {
    name = "redisVolume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.redis_volume.id
    }
  }
}

# Make sure to define the security group and subnet IDs
resource "aws_ecs_service" "redis_service" {
  name            = "redis-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.redis.arn
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

  desired_count = 1
}

resource "aws_service_discovery_service" "redis" {
  name = "redis"

  dns_config {
      namespace_id = var.service_discovery_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}