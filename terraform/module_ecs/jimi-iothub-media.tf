locals {
  # extract from var.docker_images_tags
  iothub-media_image_name = "iothub-media"
  iothub-media_image_tag = "${local.iothub-media_image_name}-${var.docker_images_tags[local.iothub-media_image_name]}"
}

resource "aws_ecs_task_definition" "iothub-media" {

  family                   = "iothub-media"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "2048"
  memory                   = "4096"

  container_definitions    = jsonencode([
    {
      name  = "iothub-media"
      image = "${var.aws_ecr_repository_url}:${local.iothub-media_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 8881
          hostPort      = 8881
        },
        {
          containerPort = 1935
          hostPort      = 1935
        },
        {
          containerPort = 10000
          hostPort      = 10000
        },
        {
          containerPort = 10001
          hostPort      = 10001
        }
      ]
      essential = true
      environment = [
        {
          name  = "newImeiRule"
          value = "true"
        }
      ]
#      entryPoint = concat(local.awscli_install_cmd, local.license_dl_cmd, ["&&","exec", "$@"])
      entryPoint = [
        "/bin/sh",
        "-c",
        "echo 'jimi-iothub-media container is starting...'; ${local.awscli_install_cmd_string}; ${local.license_dl_cmd_string}; echo 'jimi-iothub-media container started.'"
      ]
      mountPoints = [
        {
          sourceVolume  = "commonVolumeLogs"
          containerPath = "/log"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "iothub-media"
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

resource "aws_ecs_service" "iothub-media" {
  name            = "iothub-media"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.iothub-media.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

#  service_registries {
#    registry_arn   = aws_service_discovery_service.iothub-media.arn
#  }

  depends_on = [aws_ecs_task_definition.iothub-media]
}

#resource "aws_service_discovery_service" "iothub-media" {
#  name = "iothub-media"
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
