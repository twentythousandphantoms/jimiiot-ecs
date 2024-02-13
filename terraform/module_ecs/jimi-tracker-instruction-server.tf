locals {
  # extract from var.docker_images_tags
  tracker-instruction-server_image_name = "tracker-instruction-server"
  tracker-instruction-server_image_tag = "${local.tracker-instruction-server_image_name}-${var.docker_images_tags[local.tracker-instruction-server_image_name]}"
}

resource "aws_ecs_task_definition" "tracker-instruction-server" {
  depends_on = [aws_service_discovery_service.router, aws_service_discovery_service.redis]

  family                   = "tracker-instruction-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions    = jsonencode([
    {
      name  = "tracker-instruction-server"
      image = "${var.aws_ecr_repository_url}:${local.tracker-instruction-server_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 10088
          hostPort      = 10088
        },
        {
          containerPort = 10089
          hostPort      = 10089
        }
      ]
      essential = true
        environment = [
            {
            name  = "routeHost"
            value = "router"
            },
            {
            name  = "redisHost"
            value = "redis"
            },
            {
            name  = "redisPassword"
            value = "jimi@123"
            },
            {
              name  = "redisDB"
              value = "9"
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
            #This offlineCmdPushURL is used to receive replies of offline instructions. Please refer to 2.4 for the format. It should be customers' real address!!!
            {
              name  = "offlineCmdPushURL"
              value = "http://"
            },
            {
              name  = "offlineCmdPushToken"
              value = "a12341234123"
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
          awslogs-stream-prefix = "tracker-instruction-server"
        }
      }
    }
  ])

  volume {
    name = "commonVolume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.common_volume.id
      root_directory     = "/app/tracker-instruction-server/logs"
    }
  }
}

resource "aws_ecs_service" "tracker-instruction-server" {
  name            = "tracker-instruction-server"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.tracker-instruction-server.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

#  service_registries {
#    registry_arn   = aws_service_discovery_service.tracker-instruction-server.arn
#  }

  depends_on = [aws_ecs_task_definition.tracker-instruction-server]
}

#resource "aws_service_discovery_service" "tracker-instruction-server" {
#  name = "tracker-instruction-server"
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
