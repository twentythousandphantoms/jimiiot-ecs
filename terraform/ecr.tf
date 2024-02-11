variable "source_docker_images_repo" {
  type = string
  description = "The source docker images repository"
  default = "hb.jimiops.top/iothub"
}


variable "docker_images_tags" {
  type = map(string)
  default = {
    "jimi-kafka"                 = "5.0.1",
    "jimi-zookeeper"             = "5.0.1",
    "jimi-mongo"                 = "5.0.1",
    "tracker-dvr-api"            = "d91c3d77",
    "tracker-instruction-server" = "d9016cff",
    "msg-dispatch-iothub"        = "26f6aedf",
    "dvr-upload"                 = "a2d08f92",
    "tracker-gate-v1"            = "05832683",
    "tracker-gate-v541h"         = "57109ab3",
    "tracker-gate-iothub-c450"   = "eaaaeb7d",
    "iothub-media"               = "cfc71837",
    "tracker-data-mongo"         = "2e89df82",
    "tracker-gate-upload"        = "5dbf01f1",
    "tracker-upload-process"     = "e7a51632",
    "tracker-route-server"       = "e53d65bd"
  }
}

resource "aws_ecr_repository" "ecr_repo" {
  name                 = "${var.product_name}-${var.environ}"
  image_tag_mutability = "MUTABLE"

  # Optional: Enable image scanning on push to detect vulnerabilities
  image_scanning_configuration {
    scan_on_push = false
  }

  force_delete = true
}

data "aws_iam_policy_document" "ecr_repo" {
    statement {
    sid    = "ecr_repo policy"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["809375318950"]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:ListImages",
      "ecr:DeleteRepository",
      "ecr:BatchDeleteImage",
      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",
    ]
  }
}

resource "aws_ecr_repository_policy" "ecr_repo" {
  repository = aws_ecr_repository.ecr_repo.name
  policy     = data.aws_iam_policy_document.ecr_repo.json
}

resource "null_resource" "docker_login" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOF
      aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.ecr_repo.repository_url}
    EOF
  }
}

resource "null_resource" "docker_images_push" {
  depends_on = [null_resource.docker_login, aws_ecr_repository.ecr_repo]
  for_each = var.docker_images_tags

  triggers = {
    always_run = "${timestamp()}"
    region = var.region
    source_image_tag = "${var.source_docker_images_repo}/${each.key}:${each.value}"
    ecr_repo_url = aws_ecr_repository.ecr_repo.repository_url
    ecr_repo_name = aws_ecr_repository.ecr_repo.name
    ecr_image_tag = "${each.key}-${each.value}"
  }



  # Create-time provisioner
  provisioner "local-exec" {
    command = <<EOF
      if ! aws ecr describe-images --repository-name ${aws_ecr_repository.ecr_repo.name} --region ${var.region} --image-ids imageTag=${self.triggers.ecr_image_tag} | grep -q "imageTag"; then
        docker pull ${self.triggers.source_image_tag}
        docker tag ${self.triggers.source_image_tag} ${self.triggers.ecr_repo_url}:${self.triggers.ecr_image_tag}
        docker push ${self.triggers.ecr_repo_url}:${self.triggers.ecr_image_tag}
      else
        echo "Image ${each.key}-${each.value} already exists in ECR, skipping push"
      fi
    EOF
  }
}

output "ecr_repo_url" {
  value = aws_ecr_repository.ecr_repo.repository_url
}

output "null_resource_triggers_map" {
  value = {
    for k, v in null_resource.docker_images_push : k => v.triggers
  }
}
