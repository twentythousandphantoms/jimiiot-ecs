locals {
  # extract from var.docker_images_tags
  api_image_name = "tracker-dvr-api"
  api_image_tag = "${local.api_image_name}-${var.docker_images_tags[local.api_image_name]}"
}

resource "aws_ecs_task_definition" "api" {
  depends_on = [aws_service_discovery_service.router]

  family                   = "api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions    = jsonencode([
    {
      name  = "api"
      image = "${var.aws_ecr_repository_url}:${local.zk_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 9080
          hostPort      = 9080
        },
        {
          containerPort = 9081
          hostPort      = 9081
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
            name  = "mongodbUser"
            value = "root"
            },
            {
            name  = "mongodbPassword"
            value = "jimi@123"
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
          containerPath = "/"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])

  volume {
    name = "commonVolume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.common_volume.id
      root_directory     = "/iothub/api/"
    }
  }
}

resource "aws_ecs_service" "api" {
  name            = "api"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.api.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

#  service_registries {
#    registry_arn   = aws_service_discovery_service.api.arn
#  }

  depends_on = [aws_ecs_task_definition.api]
}

#resource "aws_service_discovery_service" "api" {
#  name = "api"
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
