resource "aws_security_group" "alb_sg" {
  name   = "${var.name}-alb-sg"
  vpc_id = var.vpc_id
  ingress { from_port=80  to_port=80  protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  ingress { from_port=443 to_port=443 protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  egress  { from_port=0   to_port=0   protocol="-1"  cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_lb" "alb" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check { path = "/health" matcher = "200-399" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action { type = "forward" target_group_arn = aws_lb_target_group.tg.arn }
}

output "alb_dns_name" { value = aws_lb.alb.dns_name }
output "tg_arn" { value = aws_lb_target_group.tg.arn }
output "alb_sg_id" { value = aws_security_group.alb_sg.id }