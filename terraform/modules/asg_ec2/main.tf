data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { 
      type = "Service" 
      identifiers = ["ec2.amazonaws.com"] 
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Least-privilege for pulling from ECR, SSM params, CloudWatch logs, invoke the IAM token Lambda
resource "aws_iam_role_policy" "ec2_inline" {
  name = "${var.name}-ec2-inline"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version="2012-10-17",
    Statement=[
      { Action=["ecr:GetAuthorizationToken"], Effect="Allow", Resource="*" },
      { Action=["ecr:BatchGetImage","ecr:GetDownloadUrlForLayer","ecr:DescribeImages"], Effect="Allow", Resource=var.ecr_repo_arn },
      { Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Effect="Allow", Resource="*" },
      { Action=["ssm:GetParameter","ssm:GetParameters"], Effect="Allow", Resource="*" },
      { Action=["lambda:InvokeFunction"], Effect="Allow", Resource=var.rds_iam_lambda_arn }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "app_sg" {
  name   = "${var.name}-app-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }
  egress { 
    from_port=0
    to_port=0 
    protocol="-1" 
    cidr_blocks=["0.0.0.0/0"] 
  }
}

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    apt-get update -y
    apt-get install -y docker.io awscli
    systemctl enable --now docker

    # Login to ECR
    AWS_REGION="${var.region}"
    REPO_URL="${var.ecr_repo_url}"
    IMAGE_TAG="${var.image_tag}"

    aws ecr get-login-password --region "$AWS_REGION" \
      | docker login --username AWS --password-stdin "$REPO_URL"

    docker pull "${REPO_URL}:${IMAGE_TAG}" || exit 1

    # Run container
    docker rm -f app || true
    docker run -d --name app -p 8080:8080 \
      -e AWS_REGION=${var.region} \
      -e DB_USER=${var.db_user} \
      -e DB_NAME=${var.db_name} \
      -e DB_HOST=${var.db_host} \
      -e DB_PORT=5432 \
      -e RDS_IAM_LAMBDA_ARN=${var.rds_iam_lambda_arn} \
      "${REPO_URL}:${IMAGE_TAG}"
  EOF
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${var.name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile { 
    name = aws_iam_instance_profile.ec2_profile.name 
  }
  user_data = base64encode(local.user_data)
  network_interfaces {
    security_groups = [aws_security_group.app_sg.id]
    associate_public_ip_address = false
    subnet_id = null
  }
}

resource "aws_autoscaling_group" "asg" {
  name                      = "${var.name}-asg"
  desired_capacity          = 2
  max_size                  = 3
  min_size                  = 2
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 90
  launch_template { 
    id = aws_launch_template.lt.id 
    version = "$Latest" 
  }

  tag { 
    key="Name" 
    value="${var.name}-app" 
    propagate_at_launch=true 
  }
}

resource "aws_lb_target_group_attachment" "att" {
  count            = length(var.private_subnet_ids) > 0 ? 1 : 0
  target_group_arn = var.tg_arn
  target_id        = element(aws_autoscaling_group.asg.instances, 0)
  port             = 8080
}

# Use an ASG lifecycle hook or ALB target group attachment via autoscaling attachment (optional)
resource "aws_autoscaling_attachment" "asg_alb" {
  autoscaling_group_name = aws_autoscaling_group.asg.name
  lb_target_group_arn    = var.tg_arn
}

output "app_sg_id" { value = aws_security_group.app_sg.id }