variable "product_name" {
  default = "jimiiot"
}

variable "region" {
  default = "eu-west-2"
  description = "The AWS region in which to create the VPC. Default: eu-west-2 (London)"
}

variable "environ" {
  default = "dev"
  description = "The environment in which the product will be deployed. Default: dev"
}

variable "docker_images_tags" {
  type = map(string)
  default = {
#    "jimi-kafka"                 = "5.0.1",
#    "jimi-zookeeper"             = "5.0.1",
#    "jimi-mongo"                 = "5.0.1",
#    "jimi-redis"                 = "5.0.1",
#    "tracker-dvr-api"            = "d91c3d77",
#    "tracker-instruction-server" = "d9016cff",
#    "msg-dispatch-iothub"        = "26f6aedf",
#    "dvr-upload"                 = "a2d08f92",
#    "tracker-gate-v1"            = "05832683",
#    "tracker-gate-v541h"         = "57109ab3",
#    "tracker-gate-iothub-c450"   = "eaaaeb7d",
    "iothub-media"               = "cfc71837",
#    "tracker-data-mongo"         = "2e89df82",
#    "tracker-gate-upload"        = "5dbf01f1",
#    "tracker-upload-process"     = "e7a51632",
#    "tracker-route-server"       = "e53d65bd"
  }
}
