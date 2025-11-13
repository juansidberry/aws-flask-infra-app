variable "name" {}
# might be somethgin like "../../build/lambda_rds_iam.zip"
# will come back through and iterate
variable "package_file" { type = string }