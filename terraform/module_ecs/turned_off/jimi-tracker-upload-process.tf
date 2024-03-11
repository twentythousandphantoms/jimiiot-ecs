locals {
  # extract from var.docker_images_tags
  jimi-tracker-upload-process_image_name = "tracker-upload-process"
  jimi-tracker-upload-process_image_tag = "${local.jimi-tracker-upload-process_image_name}-${var.docker_images_tags[local.jimi-tracker-upload-process_image_name]}"
}

resource "aws_ecs_task_definition" "jimi-tracker-upload-process" {
  depends_on = [aws_service_discovery_service.redis, aws_service_discovery_service.kafka]

  family                   = "jimi-tracker-upload-process"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions    = jsonencode([
    {
      name  = "jimi-tracker-upload-process"
      image = "${var.aws_ecr_repository_url}:${local.jimi-tracker-upload-process_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 21210
          hostPort      = 21210
        }
      ]
      essential = true
      environment = [
        {
          name  = "routeHost"
          value = "router.${var.service_discovery_namespace.name}"
        },
        {
          name  = "redisHost"
          value = "redis.${var.service_discovery_namespace.name}"
        },
        {
          name  = "redisPort"
          value = "6379"
        },
        {
          name  = "redisPassword"
          value = "jimi@123"
        },
        {
          name  = "kafkaHost"
          value = "kafka.${var.service_discovery_namespace.name}:9092"
        },
        {
          name  = "kafkaAuthSwitch"
          value = "false"
        },
        {
          name  = "kafkaAuthUserName"
          value = "admin"
        },
        {
          name  = "kafkaAuthPassword"
          value = "123456"
        },
        {
          name  = "kafkaEnable"
          value = "true"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "commonVolumeLogs"
          containerPath = "/app/tracker-upload-process/logs"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "jimi-tracker-upload-process"
        }
      }
    }
  ])

  volume {
    name = "commonVolumeLogs"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.common_volume.id
      root_directory     = "/"
    }
  }
}

resource "aws_ecs_service" "jimi-tracker-upload-process" {
  name            = "jimi-tracker-upload-process"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.jimi-tracker-upload-process.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

#  service_registries {
#    registry_arn   = aws_service_discovery_service.jimi-tracker-upload-process.arn
#  }

  depends_on = [aws_ecs_task_definition.jimi-tracker-upload-process]
}

#resource "aws_service_discovery_service" "jimi-tracker-upload-process" {
#  name = "jimi-tracker-upload-process"
#
#  dns_config {
#      namespace_id = var.service_discovery_namespace.id
#
#    dns_records {
#      ttl  = 10
#      type = "A"
#    }
#  }
#
#  health_check_custom_config {
#    failure_threshold = 1
#  }
#}
