#create the VPC
resource "aws_vpc" "demo" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "demo"
  }
}
resource "aws_subnet" "public-subnet-1" {

  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.0.0/25"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public-subnet-1"
  }
}
resource "aws_subnet" "public-subnet-2" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.0.128/25"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "public-subnet-2"
  }
}

###create the internet gateway###

resource "aws_internet_gateway" "demo-igw" {

  vpc_id = aws_vpc.demo.id

  tags = {
    Name = "demo-igw"
  }
}

###create the route table###

resource "aws_route_table" "Demo-rt" {

  vpc_id = aws_vpc.demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-igw.id
  }
}

### create route table associations ###

resource "aws_route_table_association" "pub-rt1" {

  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.Demo-rt.id
}
resource "aws_route_table_association" "pub-rt2" {

  subnet_id      = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.Demo-rt.id
}

# create security group

resource "aws_security_group" "web-SG" {

  vpc_id = aws_vpc.demo.id
  ingress {
    description = "HTTP for VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH for VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS for VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "web-SG"
  }
}
#create instance-1
resource "aws_instance" "WebServer-1" {

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public-subnet-1.id
  vpc_security_group_ids      = [aws_security_group.web-SG.id]
  associate_public_ip_address = true
  user_data                   = base64encode(file("userdata1.sh"))

  tags = {
    Name = "Webserver1"
  }
}
#create instance-2
resource "aws_instance" "WebServer-2" {

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public-subnet-2.id
  vpc_security_group_ids      = [aws_security_group.web-SG.id]
  associate_public_ip_address = true
  user_data                   = base64encode(file("userdata2.sh"))

  tags = {
    Name = "Webserver2"
  }
}
#create Application load balancer
resource "aws_lb" "web-alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-SG.id]
  subnets            = [aws_subnet.public-subnet-1.id, aws_subnet.public-subnet-2.id]

  enable_deletion_protection = false
}
#Target group
resource "aws_lb_target_group" "web-TG" {
  name     = "web-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.web-TG.arn
  target_id        = aws_instance.WebServer-1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.web-TG.arn
  target_id        = aws_instance.WebServer-2.id
  port             = 80
}

#Listners
resource "aws_lb_listener" "http-listener" {
  load_balancer_arn = aws_lb.web-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-TG.arn
  }
}

output "albdns" {
  value = aws_lb.web-alb.dns_name
}