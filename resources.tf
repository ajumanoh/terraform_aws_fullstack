terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.48"
    }
  }

  required_version = ">= 0.15.5"
}

################################################################
# PROVIDERS                                                    #
################################################################

provider "aws" {

  profile = "default"
  region  = var.region
  default_tags {
    tags = {
      Environment = var.environment
      Name        = "full_stack"
    }
  }
}

locals {
  user_data = filebase64("${path.module}/install_apache.sh")
}

################################################################
# DATA                                                         #
################################################################

data "aws_availability_zones" "available" {}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

################################################################
# RESOURCES                                                    #
################################################################
################################################################
# NETWORKING  - CREATE VPC                                     #
################################################################
module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  version         = "3.2.0"
  name            = "fullstack"
  cidr            = var.cidr_block
  azs             = slice(data.aws_availability_zones.available.names, 0, var.subnet_count)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  #  enable_nat_gateway           = true
  enable_nat_gateway = false
  #  create_database_subnet_group = true
  create_database_subnet_group = false

  tags = {
    Environment = "Development"
    Team        = "Networking"
  }
}

################################################################
# NETWORKING  - CREATE SECURITY GROUPS                         #
################################################################
# Securiry group of ALB      #
resource "aws_security_group" "alb" {
  name        = "alb_sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  #  ingress {
  #    description      = "HTTPS"
  #    from_port        = 443
  #    to_port          = 443
  #    protocol         = "tcp"
  #    cidr_blocks      = ["0.0.0.0/0"]
  #    ipv6_cidr_blocks = ["::/0"]
  #  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "alb_sg"
  }
}

# Public EC2 Security group           #
resource "aws_security_group" "web_ec2" {
  name        = "web_ec2"
  description = "Security group for Webserver EC2"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "TCP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web_ec2"
  }
}

# RDS Securiry group. Assuming it is a postgres DB as backend #

resource "aws_security_group" "rds" {
  name        = "backend_rds"
  description = "Security group for backend RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "PostgreSQL RDS"
  }
}

################################################################
# Auto Scaling Group                                           #
################################################################

# Launch template for Apache Webserver #

resource "aws_launch_template" "web_template" {
  name_prefix   = "webserver"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  user_data     = local.user_data
  key_name      = var.keypair
  vpc_security_group_ids = [aws_security_group.web_ec2.id]
}

resource "aws_lb_target_group" "web_alb_tg" {
  name        = "web-alb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    interval            = "30"
    path                = "/"
    port                = "80"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
    timeout             = "10"
    protocol            = "HTTP"
    matcher             = "200"
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name = "web-asg"
  #  availability_zones = module.vpc.azs
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = module.vpc.public_subnets

  launch_template {
    id      = aws_launch_template.web_template.id
    version = "$Latest"
  }
}

# Create a new load balancer
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  #  enable_deletion_protection = true

  #  access_logs {
  #    bucket  = aws_s3_bucket.lb_logs.bucket
  #    prefix  = "test-lb"
  #    enabled = true
  #  }

}

resource "aws_lb_listener" "web_alb-listner" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_alb_tg.arn

    #    redirect {
    #      port        = "443"
    #      protocol    = "HTTPS"
    #      status_code = "HTTP_301"
    #    }
  }
}

resource "aws_lb_listener_rule" "web_alb-listner-rule" {
  listener_arn = aws_lb_listener.web_alb-listner.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_alb_tg.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}


# Create a new ALB Target Group attachment
resource "aws_autoscaling_attachment" "asg_attachment_web" {
  autoscaling_group_name = aws_autoscaling_group.web_asg.id
  alb_target_group_arn   = aws_lb_target_group.web_alb_tg.arn
}
