locals {
  # extract from var.docker_images_tags
  tracker-gate-v1_image_name = "tracker-gate-v1"
  tracker-gate-v1_image_tag = "${local.tracker-gate-v1_image_name}-${var.docker_images_tags[local.tracker-gate-v1_image_name]}"
}

resource "aws_ecs_task_definition" "tracker-gate-v1" {
  depends_on = [aws_service_discovery_service.kafka]

  family                   = "tracker-gate-v1"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions    = jsonencode([
    {
      name  = "tracker-gate-v1"
      image = "${var.aws_ecr_repository_url}:${local.tracker-gate-v1_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 21100
          hostPort      = 21100
        },
        {
          containerPort = 22201
          hostPort      = 22201
        }
      ]
      essential = true
      environment = [
            {
            name  = "gateId"
            value = "tracker-gate-v1-93"
            },
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
            #LBS value-added service, please contact customer service to open!
            {
              name  = "lbsURL"
              value = "http://xxx"
            },
            {
              name  = "lbsToken"
              value = ""
            },
            {
              #license expiration monitor switch
              name  = "licenseFlag"
              value = "true"
            },
            {
              #license expiration notification ountdown configuration (Days)
              name  = "licenseNoticeCountdownDay"
              value = "90"
            },
            {
              #license expiration notification timed task, daily start time
              name  = "licenseNoticeStartTime"
              value = "23:59:59"
            },
            {
              #license expiration notification timed task interval (hours)
              name  = "licenseNoticeDelay"
              value = "24"
            },
        ]
      entryPoint = [
        "aws",
        "s3",
        "cp",
        "s3://${aws_s3_bucket.license_bucket.bucket}/${var.license_name}",
        "/app/tracker-gate-v1/conf/license/${var.license_name}",
        "&&",
        "exec",
        "$@"
      ]
      mountPoints = [
        {
          sourceVolume  = "commonVolumeLogs"
          containerPath = "/iothub/tracker-gate-v1/logs"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "tracker-gate-v1"
        }
      }
    }
  ])

  volume {
    name = "commonVolumeLogs"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.common_volume.id
      root_directory     = "/app/tracker-gate-v1/logs"
    }
  }
}

resource "aws_ecs_service" "tracker-gate-v1" {
  name            = "tracker-gate-v1"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.tracker-gate-v1.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

#  service_registries {
#    registry_arn   = aws_service_discovery_service.tracker-gate-v1.arn
#  }

  depends_on = [aws_ecs_task_definition.tracker-gate-v1]
}

#resource "aws_service_discovery_service" "tracker-gate-v1" {
#  name = "tracker-gate-v1"
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
