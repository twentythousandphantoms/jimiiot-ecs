resource "aws_ecr_repository" "ecr_repo" {
  name                 = "${var.name}"
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
#    run_every_day = "${formatdate("MMM DD", timestamp())}"
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
#    run_every_day = "${formatdate("MMM DD", timestamp())}"
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

#output "null_resource_triggers_map" {
#  value = {
#    for k, v in null_resource.docker_images_push : k => v.triggers
#  }
#}
