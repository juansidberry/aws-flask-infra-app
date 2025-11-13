resource "aws_iam_role" "lambda_role" {
  name = "${var.name}-lambda-role"
  assume_role_policy = jsonencode({
    Version="2012-10-17",
    Statement=[{Action="sts:AssumeRole", Effect="Allow", Principal={Service="lambda.amazonaws.com"}}]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "rds_gen" {
  name = "${var.name}-lambda-inline"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version="2012-10-17",
    Statement=[{
      Effect="Allow",
      Action=["rds:GenerateDbAuthToken"],
      Resource="*"
    }]
  })
}

resource "aws_lambda_function" "this" {
  function_name = "${var.name}-rds-iam-token"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"

  filename         = var.package_file       # zip of lambda/rds_iam_token
  source_code_hash = filebase64sha256(var.package_file)
  timeout          = 10
}

output "lambda_arn" { value = aws_lambda_function.this.arn }