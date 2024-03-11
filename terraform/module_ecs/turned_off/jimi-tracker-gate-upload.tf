locals {
  # extract from var.docker_images_tags
  tracker-gate-upload_image_name = "tracker-gate-upload"
  tracker-gate-upload_image_tag = "${local.tracker-gate-upload_image_name}-${var.docker_images_tags[local.tracker-gate-upload_image_name]}"
}

resource "aws_ecs_task_definition" "tracker-gate-upload" {
  depends_on = [aws_service_discovery_service.redis, aws_service_discovery_service.kafka]

  family                   = "tracker-gate-upload"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions    = jsonencode([
    {
      name  = "tracker-gate-upload"
      image = "${var.aws_ecr_repository_url}:${local.tracker-gate-upload_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 21188
          hostPort      = 21188
        },
        {
          containerPort = 21189
          hostPort      = 21189
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
        },
        {
          name  = "connectTimeout"
          value = "5"
        },
        {
          name  = "readTimeOut"
          value = "5"
        },
        {
          name  = "writeTimeOut"
          value = "5"
        },
        {
          name  = "newImeiRule"
          value = "true"
        },
        {
          # This pushUploadStatusURL is used to receive the results of file push.
          # The interfacerefers to pushIothubEvent.
          # It should be customers' actual URL!!!
          name  = "pushUploadStatusURL"
          value = "http://xxx"
        },
        {
          name  = "pushUploadStatusToken"
          value = "a12341234123"
        },
        {
          # HTTP push data encrypted switch
          name  = "httpPushEncrypt"
          value = "false"
        },
        {
          # Encryption Key
          name  = "httpPushSecret"
          value = "JIMI@20231234567"
        },
      ]
      mountPoints = [
        {
          sourceVolume  = "commonVolumeLogs"
          containerPath = "/iothub/tracker-gate-upload/logs"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "tracker-gate-upload"
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

resource "aws_ecs_service" "tracker-gate-upload" {
  name            = "tracker-gate-upload"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.tracker-gate-upload.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

#  service_registries {
#    registry_arn   = aws_service_discovery_service.tracker-gate-upload.arn
#  }

  depends_on = [aws_ecs_task_definition.tracker-gate-upload]
}

#resource "aws_service_discovery_service" "tracker-gate-upload" {
#  name = "tracker-gate-upload"
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
