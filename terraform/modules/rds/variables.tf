variable "name" {}
variable "vpc_id" {}
variable "private_subnet_ids" {
  type = list(string)
}
variable "app_sg_id" {}
variable "instance_class" {}
variable "master_username" {}
variable "master_password" {}