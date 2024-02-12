locals {
  # extract from var.docker_images_tags
  zk_image_name = "jimi-zookeeper"
  zk_image_tag = "${local.zk_image_name}-${var.docker_images_tags[local.zk_image_name]}"
}

resource "aws_efs_file_system" "zookeeper_volume" {
  creation_token = "zookeeperVolume"
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
  encrypted = false
  lifecycle_policy {
      transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
      Name = "zookeeperVolume"
  }
}

resource "aws_efs_mount_target" "zookeeper_volume" {
  count          = length(var.aws_subnets)
  file_system_id = aws_efs_file_system.zookeeper_volume.id
  subnet_id = element(var.aws_subnets, count.index)
  security_groups = [var.aws_security_group_id]
}

resource "aws_ecs_task_definition" "zookeeper" {
  family                   = "zookeeper"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions    = jsonencode([
    {
      name  = "zookeeper"
      image = "${var.aws_ecr_repository_url}:${local.zk_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 2181
          hostPort      = 2181
        },
        {
          containerPort = 2888
          hostPort      = 2888
        },
        {
          containerPort = 3888
          hostPort      = 3888
        }
      ]
      essential = true
        environment = [
            {
            name  = "ZOO_MY_ID"
            value = "1"
            }
        ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "zookeeper"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "zookeeper" {
  name            = "zookeeper"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.zookeeper.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.aws_subnets
    security_groups  = [var.aws_security_group_id]
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.zookeeper.arn
  }

  depends_on = [aws_ecs_task_definition.zookeeper]
}

resource "aws_service_discovery_service" "zookeeper" {
  name = "zookeeper"

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
