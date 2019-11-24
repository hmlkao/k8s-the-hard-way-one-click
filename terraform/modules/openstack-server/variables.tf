variable "name" {}

variable "region" {}

variable "flavor_name" {}

variable "regions" {
  default = [
    "RegionOne",
    "RegionTwo",
  ]
}

variable "ssh_key" {
  description = "Name of SSH key which will be provisioned to VM"
}

variable "image_name" {
  description = "Name of image which will be used to boot VM"
}
