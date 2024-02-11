# Security Group
resource "aws_security_group" "jimi_kafka_sg" {
  name        = "jimi_kafka_sg"
  description = "Allow inbound traffic for Jimi Kafka"
  vpc_id      = aws_vpc.jimi_vpc.id

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "jimi_kafka_sg",
    Component = "Kafka"
  }
}

resource "aws_efs_file_system" "kafka_volume" {
  creation_token = "kafkaVolume"

  tags = {
    Name = "KafkaVolume"
  }
}

resource "aws_ecs_task_definition" "kafka" {
  family                   = "kafka-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name         = "kafka"
      image        = "${aws_ecr_repository.ecr_repo.repository_url}:jimi-kafka"
      cpu          = 256
      memory       = 512
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
      ]
      mountPoints = [
        {
          sourceVolume  = "kafkaVolume"
          containerPath = "/kafka"
          readOnly      = false
        },
      ]
    },
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
    subnets          = [aws_subnet.jimi_subnet_1.id, aws_subnet.jimi_subnet_2.id]
    security_groups  = [aws_security_group.jimi_kafka_sg.id]
  }

  desired_count = 1
}