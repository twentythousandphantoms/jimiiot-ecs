resource "aws_efs_file_system" "kafka_volume" {
  creation_token = "kafkaVolume"

  tags = {
    Name = "KafkaVolume"
  }
}

# mount target
resource "aws_efs_mount_target" "kafka_volume" {
  count          = length(var.aws_subnets)
  file_system_id = aws_efs_file_system.kafka_volume.id
  subnet_id      = var.aws_subnets[count.index]
  security_groups = [var.aws_security_group_id]
}

locals {
  # extract from var.docker_images_tags
  kafka_image_name = "jimi-kafka"
  kafka_image_tag = "${local.kafka_image_name}-${var.docker_images_tags[local.kafka_image_name]}"
}

resource "aws_ecs_task_definition" "kafka" {
  family                   = "kafka-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "1024"
  memory                   = "2048"

  container_definitions = jsonencode([
    {
      name         = "kafka"
      image        = "${var.aws_ecr_repository_url}:${local.kafka_image_tag}"
      cpu          = 1024
      memory       = 2048
      essential    = true
      portMappings = [
        {
          containerPort = 9092
          hostPort      = 9092
        },
      ]
      environment = [
        {
          name  = "KAFKA_ADVERTISED_HOST_NAME"
          value = "kafka"
        },
        {
          name  = "KAFKA_ADVERTISED_PORT"
          value = "9092"
        },
        {
          name  = "KAFKA_ZOOKEEPER_CONNECT"
          value = "zookeeper.${var.service_discovery_namespace.name}:2181"
        },
        {
          name  = "KAFKA_PORT"
          value = "9092"
        },
        {
          name  = "KAFKA_LOG_RETENTION_HOURS"
          value = "120"
        },
        {
          name  = "KAFKA_MESSAGE_MAX_BYTES"
          value = "10000000"
        },
        {
          name  = "KAFKA_REPLICA_FETCH_MAX_BYTES"
          value = "10000000"
        },
        {
          name  = "KAFKA_GROUP_MAX_SESSION_TIMEOUT_MS"
          value = "60000"
        },
        {
          name  = "KAFKA_NUM_PARTITIONS"
          value = "10"
        },
        {
          name  = "KAFKA_DELETE_RETENTION_MS"
          value = "1000"
        },
        {
          name  = "HOSTNAME"
          value = "kafka"
        },
      ]
      mountPoints = [
        {
          sourceVolume  = "kafkaVolume"
          containerPath = "/kafka"
          readOnly      = false
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "kafka"
        }
      }
    }
  ])

  volume {
    name = "kafkaVolume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.kafka_volume.id
      transit_encryption = "ENABLED"
    }
  }
}

# Make sure to define the security group and subnet IDs
resource "aws_ecs_service" "kafka_service" {
  name            = "kafka-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.kafka.arn
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

  desired_count = 1
}