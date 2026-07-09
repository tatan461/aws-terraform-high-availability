# ==========================================
# 1. NETWORKING (VPC & SUBNETS)
# ==========================================

# Create the main Virtual Private Cloud (VPC)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# Create Public Subnets (For the Load Balancer)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

# Create Private Subnets (For backend isolation if needed later)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "private-subnet-1"
  }
}

# Create Private Subnets (For backend isolation if needed later)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "private-subnet-2"
  }
}

# ==========================================
# 2. ROUTING & INTERNET ACCESS
# ==========================================

# Create the Internet Gateway to allow public traffic
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Create the Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Public Subnets to the Public Route Table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# ==========================================
# 3. SECURITY GROUPS (FIREWALL RULES)
# ==========================================

# Security Group for the Application Load Balancer (ALB) - Public Access
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Allow inbound HTTP traffic from the internet"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP inbound from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Security Group for the Web Servers - Private Access (ALB only)
resource "aws_security_group" "web_sg" {
  name        = "web-server-security-group"
  description = "Allow HTTP traffic ONLY from the ALB"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP inbound only if it comes from the ALB Security Group
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-servers-sg"
  }
}

# ==========================================
# 4. COMPUTE (LAUNCH TEMPLATE & AUTO SCALING)
# ==========================================

# Data source to fetch the latest Amazon Linux 2023 AMI (ARM64 for t4g.micro)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-arm64"] # Cambiado a arm64
  }
}

# Create a Launch Template for the EC2 instances
resource "aws_launch_template" "web_lt" {
  name_prefix   = "web-server-template-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t4g.micro" # Cambiado a t4g.micro

  # Attach the Web Security Group we created earlier
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Script to install Apache and a basic website upon boot
  user_data = base64encode(<<-EOF
#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello World from AWS Architecture Project!</h1>" > /var/www/html/index.html
EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-server-asg"
    }
  }
}

# Create the Auto Scaling Group (ASG) across PUBLIC subnets (to allow package downloads)
resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "web-asg-"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  # Health checks based on EC2 status
  health_check_type         = "EC2"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}

# ==========================================
# 5. LOAD BALANCING (ALB, TARGET GROUP & LISTENER)
# ==========================================

# Create the Application Load Balancer in Public Subnets
resource "aws_lb" "web_alb" {
  name               = "web-server-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "web-alb"
  }
}

# Create the Target Group (Where traffic is directed)
resource "aws_lb_target_group" "web_tg" {
  name     = "web-servers-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health check settings to monitor instance status
  health_check {
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create the HTTP Listener to redirect traffic from ALB to Target Group
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Attach our Auto Scaling Group to the Load Balancer Target Group
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.web_asg.id
  lb_target_group_arn    = aws_lb_target_group.web_tg.arn
}

# ==========================================
# 6. OUTPUTS
# ==========================================

# Output the DNS Name of the Load Balancer so you can access the website
output "alb_dns_name" {
  value       = aws_lb.web_alb.dns_name
  description = "The public URL to access your web application"
}