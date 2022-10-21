# ---------- AWS EC2 Instances ----------
# WebServer Instance 1
resource "aws_instance" "WebServer01" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_02.id
  security_groups             = [aws_security_group.WebServer_SG.id]
  user_data                   = file("userdata.tpl")
  associate_public_ip_address = true
  key_name                    = aws_key_pair.TF_keypair.key_name

  tags = {
    Name = "WebServer01"
  }
}

# WebServer Instance 2
resource "aws_instance" "WebServer02" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_02.id
  security_groups             = [aws_security_group.WebServer_SG.id]
  user_data                   = file("userdata2.tpl")
  associate_public_ip_address = true
  key_name                    = aws_key_pair.TF_keypair.key_name

  tags = {
    Name = "WebServer02"
  }
}

# Database Instance 
resource "aws_db_instance" "Database_EC2" {
  allocated_storage      = 10
  db_name                = "Private_DB"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql5.7"
  db_subnet_group_name   = aws_db_subnet_group.DB_Subnet.name
  vpc_security_group_ids = [aws_security_group.WebServer_SG.id]
  skip_final_snapshot    = true
}

# Key Pair for SSH
resource "aws_key_pair" "TF_keypair" {
  key_name   = "tfkey"
  public_key = file("~/.ssh/tf_keypair.pub")
}

# ----------- Network Configuration ----------
# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# Public Subnet 1
resource "aws_subnet" "public_01" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "PublicSubnet01"
  }
}

# Public Subnet 2
resource "aws_subnet" "public_02" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "PublicSubnet02"
  }
}

# Private Subnet 1
resource "aws_subnet" "private_01" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1d"

  tags = {
    Name = "PrivateSubnet01"
  }
}

# Private Subnet 2
resource "aws_subnet" "private_02" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1e"

  tags = {
    Name = "PrivateSubnet02"
  }
}

# Database Instance Subnet
resource "aws_db_subnet_group" "DB_Subnet" {
  name       = "db_subnet_group"
  subnet_ids = [aws_subnet.private_01.id, aws_subnet.private_02.id]
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Internet_Gateway"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public_rt1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "My_Route_Table"
  }
}

# Route Table association with Subnet
resource "aws_route_table_association" "public_rt01" {
  subnet_id      = aws_subnet.public_01.id
  route_table_id = aws_route_table.public_rt1.id
}

# Route Table association with Subnet
resource "aws_route_table_association" "public_rt02" {
  subnet_id      = aws_subnet.public_02.id
  route_table_id = aws_route_table.public_rt1.id
}

# ---------- WebServer Security Groups ----------
resource "aws_security_group" "WebServer_SG" {
  name        = "allow_HTTP"
  description = "Enable HTTP for WebServer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebServer_SG"
  }
}

# ---------- Database Security Group ----------
resource "aws_security_group" "db_sg" {
  name        = "db_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.WebServer_SG.id]
  }

 ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- Application Load Balancer and Target Group ----------
# Application Load Balancer
resource "aws_lb" "ALB" {
  name               = "WebServerALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.WebServer_SG.id]
  subnets            = [aws_subnet.public_01.id, aws_subnet.public_02.id]

  tags = {
    Name = "Web ALB"
  }
}

# Application Load Balancer Target Group
resource "aws_lb_target_group" "ALB_Target" {
  name     = "aws-lb-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Application Load Balancer Listener Rule
resource "aws_lb_listener" "ALB_Listener" {
  load_balancer_arn = aws_lb.ALB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ALB_Target.arn
  }
}

# Load Balancer Target Group Attachment
resource "aws_lb_target_group_attachment" "ALB_Attach1" {
  target_group_arn = aws_lb_target_group.ALB_Target.arn
  target_id        = aws_instance.WebServer01.id
  port = 80
}

# Load Balancer Target Group Attachment
resource "aws_lb_target_group_attachment" "ALB_Attach2" {
  target_group_arn = aws_lb_target_group.ALB_Target.arn
  target_id        = aws_instance.WebServer02.id
  port = 80
}
