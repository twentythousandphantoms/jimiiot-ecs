



variable "region" {
  default = "eu-west-2"
  description = "The AWS region in which to create the VPC. Default: eu-west-2 (London)"
}

variable "availability_zone_1" {
  default = "eu-west-2a"
}

variable "availability_zone_2" {
  default = "eu-west-2b"
}