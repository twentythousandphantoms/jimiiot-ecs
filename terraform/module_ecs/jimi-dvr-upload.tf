locals {
  # extract from var.docker_images_tags
  dvr-upload_image_name = "dvr-upload"
  dvr-upload_image_tag = "${local.dvr-upload_image_name}-${var.docker_images_tags[local.dvr-upload_image_name]}"
}

resource "aws_ecs_task_definition" "dvr-upload" {
  depends_on = [aws_service_discovery_service.kafka]

  family                   = "dvr-upload"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "1024"

  container_definitions    = jsonencode([
    {
      name  = "dvr-upload"
      image = "${var.aws_ecr_repository_url}:${local.zk_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 23010
          hostPort      = 23010
        },
        {
          containerPort = 23011
          hostPort      = 23011
        }
      ]
      essential = true
      environment = [
            {
            name  = "ENABLE_SECRET"
            value = "true"
            },
            {
            name  = "LOCAL_ENABLE"
            value = "true"
            },
            {
            name  = "OSS_ENABLE"
            value = "false"
            },
            {
            name  = "OSS_ENDPOINT"
            value = "https://xxx"
            },
            {
              name  = "OSS_ACCESS_KEY"
              value = "<your AccessKeyId>"
            },
            {
              name  = "OSS_BUCKET_NAME"
              value = "<yourBucketName>"
            },
            {
              name  = "OSS_ACCESS_SECRET"
              value = "<yourAccessKeySecret>"
            },
            {
              name  = "AWS_ENABLE"
              value = "false"
            },
            {
              name  = "AWS_REGION"
              value = "<yourAWSRegion>"
            },
            {
              name  = "AWS_BUCKET_NAME"
              value = "<yourAWSBucketName>"
            },
            {
              name  = "AWS_ACCESS_KEY_ID"
              value = "<yourAWSAccessKeyId>"
            },
            {
              name  = "AWS_SECRET_ACCESS_KEY"
              value = "<yourAWSSecret>"
            },
        ]
      mountPoints = [
        {
          sourceVolume  = "commonVolumeLogs"
          containerPath = "/logs"
          readOnly      = false
        },
#        {
#          sourceVolume  = "commonVolumeUpload"
#          containerPath = "/data/upload"
#          readOnly      = false
#        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "dvr-upload"
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
#  volume {
#    name = "commonVolumeUpload"
#
#    efs_volume_configuration {
#      file_system_id     = aws_efs_file_system.common_volume.id
#      root_directory     = "/uploadFile"
#    }
#  }
}

resource "aws_ecs_service" "dvr-upload" {
  name            = "dvr-upload"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.dvr-upload.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

#  service_registries {
#    registry_arn   = aws_service_discovery_service.dvr-upload.arn
#  }

  depends_on = [aws_ecs_task_definition.dvr-upload]
}

#resource "aws_service_discovery_service" "dvr-upload" {
#  name = "dvr-upload"
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
