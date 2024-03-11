locals {
  # extract from var.docker_images_tags
  iothub_data_image_name = "tracker-data-mongo"
  iothub_data_image_tag = "${local.iothub_data_image_name}-${var.docker_images_tags[local.iothub_data_image_name]}"
}

resource "aws_ecs_task_definition" "jimi-data" {
  depends_on = [aws_service_discovery_service.kafka, aws_service_discovery_service.mongodb]

  family                   = "jimi-data"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "512"
  memory                   = "1024"
  
  container_definitions    = jsonencode([
    {
      name  = "jimi-data"
      image = "${var.aws_ecr_repository_url}:${local.iothub_data_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 21300
          hostPort      = 21300
        },
        {
          containerPort = 2049
          hostPort      = 2049
        }
      ]
      essential = true
        environment = [
          {
            name  = "kafka"
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
            name  = "mongoHost"
            value = "mongodb"
          },
          {
            name  = "mongoPort"
            value = "27017"
          },
          {
            name  = "mongoUser"
            value = "root"
          },
          {
            name  = "mongoPass"
            value = "jimi@123"
          },
          {
            name  = "mongoTtlday"
            value = "2"
          },
#          {
#            #This URL isused to receive data parsed by LBS/WIFI. Please refer to 1.1.3 pushgps for thedata format. This function involves LBS value-added services and requiresadditional charges!!!
#            #After opening the LBS service, it should be customers' actual address!!!
#            name  = "pushLbsWifiURL"
#            value = "http://xxx"
#          },
#          {
#            name  = "pushLbsWifiToken"
#            value = "a12341234123"
#          },
#          {
#            #TLBS value-added service, please contact customer service to open!
#            name  = "lbsWifiServiceURL"
#            value = "http://xxx"
#          },
#          {
#            name  = "lbsWifiServiceToken"
#            value = "a12341234123"
#          }
        ]
      mountPoints = [
        {
          sourceVolume  = "commonVolume"
          containerPath = "/app/jimi-data/logs"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "jimi-data"
        }
      }
    }
  ])

  volume {
    name = "commonVolume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.common_volume.id
      root_directory     = "/"
#      transit_encryption = "ENABLED"
#      transit_encryption_port = 2049
#      authorization_config {
#        access_point_id = aws_efs_access_point.jimi-data.id
#        iam             = "ENABLED"
#      }
    }
  }
}

resource "aws_efs_access_point" "jimi-data" {
  file_system_id = aws_efs_file_system.common_volume.id
  root_directory {
    path = "/app/jimi-data"
  }
  tags = {
    Name = "jimi-data"
  }
}

resource "aws_ecs_service" "jimi-data" {
  name            = "jimi-data"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.jimi-data.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.jimi-data.arn
  }

  depends_on = [aws_ecs_task_definition.jimi-data]
}

resource "aws_service_discovery_service" "jimi-data" {
  name = "jimi-data"

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
