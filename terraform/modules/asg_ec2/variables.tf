variable "name" {}
variable "region" {}
variable "vpc_id" {}
variable "private_subnet_ids" { 
  type = list(string) 
}
variable "alb_sg_id" {}
variable "tg_arn" {}
variable "ecr_repo_url" {}
variable "ecr_repo_arn" {}
variable "image_tag" {}
variable "ami_id" {}
variable "instance_type" {}
variable "db_user" {}
variable "db_name" {}
variable "db_host" {}
variable "rds_iam_lambda_arn" {}