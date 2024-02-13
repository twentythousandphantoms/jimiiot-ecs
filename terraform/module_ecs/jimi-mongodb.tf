resource "aws_efs_file_system" "mongodb_volume" {
  creation_token = "mongodbVolume"

  tags = {
    Name = "mongodbVolume"
  }
}

# mount target
resource "aws_efs_mount_target" "mongodb_volume" {
  count          = length(var.aws_subnets)
  file_system_id = aws_efs_file_system.mongodb_volume.id
  subnet_id      = var.aws_subnets[count.index]
  security_groups = [var.aws_security_group_id]
}

locals {
  # extract from var.docker_images_tags
  mongodb_image_name = "jimi-mongo"
  mongodb_image_tag = "${local.mongodb_image_name}-${var.docker_images_tags[local.mongodb_image_name]}"
}

resource "aws_ecs_task_definition" "mongodb" {
  family                   = "mongodb-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name         = "mongodb"
      image        = "${var.aws_ecr_repository_url}:${local.mongodb_image_tag}"
      cpu          = 256
      memory       = 512
      essential    = true
      portMappings = [
        {
          containerPort = 27017
          hostPort      = 27017
        },
      ]
      environment = [
        # TODO: AWS Secrets Manager
        {
          name  = "MONGO_INITDB_ROOT_USERNAME"
          value = "root"
        },
        {
          name  = "MONGO_INITDB_ROOT_PASSWORD"
          value = "jimi@123"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "mongodbVolume"
          containerPath = "/data/db"
          readOnly      = false
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "mongodb"
        }
      }
    }
  ])

  volume {
    name = "mongodbVolume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.mongodb_volume.id
    }
  }
}

# Make sure to define the security group and subnet IDs
resource "aws_ecs_service" "mongodb_service" {
  name            = "mongodb-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.mongodb.arn
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

  desired_count = 1
}

resource "aws_service_discovery_service" "mongodb" {
  name = "mongodb"

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