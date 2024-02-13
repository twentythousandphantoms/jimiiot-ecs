locals {
  # extract from var.docker_images_tags
  router_image_name = "tracker-route-server"
  router_image_tag = "${local.router_image_name}-${var.docker_images_tags[local.router_image_name]}"
}

resource "aws_ecs_task_definition" "router" {
  family                   = "router-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name         = "router"
      image        = "${var.aws_ecr_repository_url}:${local.router_image_tag}"
      cpu          = 256
      memory       = 512
      essential    = true
      portMappings = [
        {
          containerPort = 21200
          hostPort      = 21200
        },
        {
          containerPort = 21220
          hostPort      = 21220
        },
      ]
      # TODO: AWS Secrets Manager
      environment = [
        {
          name  = "redisHost"
          value = "redis"
        },
        {
          name  = "redisPasswd"
          value = "jimi@123"
        },
        {
          name  = "redisPort"
          value = "6379"
        },
        {
          name  = "loginRedisDB"
          value = "2"
        },

      ]
      mountPoints = [
        {
          sourceVolume  = "commonVolume"
          containerPath = "/app/tracker-router-server/logs"
          readOnly      = false
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "router"
        }
      }
    }
  ])

  volume {
    name = "commonVolume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.common_volume.id
        root_directory     = "/iothub/router/logs"
    }
  }
}

# Make sure to define the security group and subnet IDs
resource "aws_ecs_service" "router_service" {
  name            = "router-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.router.arn
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

  desired_count = 1
}

resource "aws_service_discovery_service" "router" {
  name = "router"

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