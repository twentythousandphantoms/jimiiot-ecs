variable "name" {}
variable "region" {}

variable "source_docker_images_repo" {
  type = string
  description = "The source docker images repository"
  default = "hb.jimiops.top/iothub"
}

variable "docker_images_tags" {
  type = map(string)
}
