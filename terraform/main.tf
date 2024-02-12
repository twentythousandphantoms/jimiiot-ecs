provider "aws" {
  region = var.region
}

module "ecr" {
  source = "./module_ecr"
  region = var.region
  name = "${var.product_name}-${var.environ}"
  docker_images_tags = var.docker_images_tags
}

module "network" {
  source = "./module_network"
  region = var.region
  name = "${var.product_name}-${var.environ}"
}

module "ecs" {
  source = "./module_ecs"
  region = var.region
#  name = "${var.product_name}-${var.environ}"

  aws_ecr_repository_url = module.ecr.repository_url
  docker_images_tags = var.docker_images_tags

  aws_subnets = module.network.aws_subnets
  aws_security_group_id = module.network.aws_security_group_id
  service_discovery_namespace = module.network.service_discovery_namespace
}