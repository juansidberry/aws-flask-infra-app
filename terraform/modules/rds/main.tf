resource "aws_db_subnet_group" "db" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "db_sg" {
  name        = "${var.name}-db-sg"
  description = "DB access from app"
  vpc_id      = var.vpc_id

  ingress {
    description = "Postgres from app sg"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [var.app_sg_id]
  }

  egress { 
    from_port=0 
    to_port=0 
    protocol="-1" 
    cidr_blocks=["0.0.0.0/0"] 
  }
}

resource "aws_db_instance" "this" {
  identifier              = "${var.name}-pg"
  engine                  = "postgres"
  engine_version          = "16.3"
  instance_class          = var.instance_class
  allocated_storage       = 20
  db_subnet_group_name    = aws_db_subnet_group.db.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  storage_encrypted       = true
  publicly_accessible     = false
  multi_az                = false
  iam_database_authentication_enabled = true

  username                = var.master_username
  password                = var.master_password
  skip_final_snapshot     = true
}

output "endpoint" { value = aws_db_instance.this.address }
output "db_sg_id" { value = aws_security_group.db_sg.id }