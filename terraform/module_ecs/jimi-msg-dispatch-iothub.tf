locals {
  # extract from var.docker_images_tags
  msg-dispatch-iothub_image_name = "msg-dispatch-iothub"
  msg-dispatch-iothub_image_tag = "${local.msg-dispatch-iothub_image_name}-${var.docker_images_tags[local.msg-dispatch-iothub_image_name]}"
}

resource "aws_ecs_task_definition" "msg-dispatch-iothub" {
  depends_on = [aws_service_discovery_service.kafka]

  family                   = "msg-dispatch-iothub"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions    = jsonencode([
    {
      name  = "msg-dispatch-iothub"
      image = "${var.aws_ecr_repository_url}:${local.msg-dispatch-iothub_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 10066
          hostPort      = 10066
        },
        {
          containerPort = 10067
          hostPort      = 10067
        }
      ]
      essential = true
        environment = [
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
              name  = "pushURL"
              value = "http://stg.api.wardentracking.com/jimi-iot"
            },
            {
              name  = "pushToken"
              value = "a12341234123"
            },
            {
              name  = "topicPrefix"
              value = "iothub"
            },
            {
              name  = "emailSendUrl"
              value = ""
            },
            {
              name  = "LICENSE_NOTIFY_EMAIL"
              value = "liyanmei@jimilab.com"
            },
            {
              name  = "httpPushEncrypt"
              value = "false"
            },
            {
              name  = "httpPushSecret"
              value = "JiMi@20232012345"
            },
        ]
      mountPoints = [
        {
          sourceVolume  = "commonVolume"
          containerPath = "/app/tracker-route-server/logs"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "msg-dispatch-iothub"
        }
      }
    }
  ])

  volume {
    name = "commonVolume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.common_volume.id
      root_directory     = "/app/msg-dispatch-iothub/"
    }
  }
}

resource "aws_ecs_service" "msg-dispatch-iothub" {
  name            = "msg-dispatch-iothub"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.msg-dispatch-iothub.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

#  service_registries {
#    registry_arn   = aws_service_discovery_service.msg-dispatch-iothub.arn
#  }

  depends_on = [aws_ecs_task_definition.msg-dispatch-iothub]
}

#resource "aws_service_discovery_service" "msg-dispatch-iothub" {
#  name = "msg-dispatch-iothub"
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
