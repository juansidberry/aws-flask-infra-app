resource "aws_ecr_repository" "app" {
  name = var.name
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = { Name = var.name }
}

output "repository_url" { value = aws_ecr_repository.app.repository_url }
output "repository_arn" { value = aws_ecr_repository.app.arn }