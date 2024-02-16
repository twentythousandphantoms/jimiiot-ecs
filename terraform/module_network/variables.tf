variable "region" {}
variable "name" {}
variable "availability_zones" {
  default = ["eu-west-2a"]
#  default = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

