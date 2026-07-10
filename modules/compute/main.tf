resource "aws_security_group" "web" {
  name        = "${var.environment}-web-sg"
  description = "Restrict access strictly to ALB requests"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-web-sg"
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.environment}-tpl-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t4g.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name_prefix         = "${var.environment}-asg-"
  vpc_zone_identifier = var.public_subnet_ids
  target_group_arns   = [var.target_group_arn]
  
  desired_capacity = 2
  max_size         = 3
  min_size         = 2

  health_check_type         = "ELB"
  health_check_grace_period = 150

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }
}
