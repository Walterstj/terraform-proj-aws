resource "aws_vpc" "integrated-vpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "IntSub1" {
  vpc_id                  = aws_vpc.integrated-vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "IntSub2" {
  vpc_id                  = aws_vpc.integrated-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "intigw" {
  vpc_id = aws_vpc.integrated-vpc.id
}

resource "aws_route_table" "IntetRT" {
  vpc_id = aws_vpc.integrated-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.intigw.id
  }
}

resource "aws_route_table_association" "RTas1" {
  subnet_id      = aws_subnet.IntSub1.id
  route_table_id = aws_route_table.IntetRT.id
}

resource "aws_route_table_association" "RTas2" {
  subnet_id      = aws_subnet.IntSub2.id
  route_table_id = aws_route_table.IntetRT.id
}

resource "aws_security_group" "integrated_sg" {
  name   = "integrated_sg"
  vpc_id = aws_vpc.integrated-vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "Web-sg"
  }
}

resource "aws_s3_bucket" "examplebucket" {
  bucket = "intergrated-heath-care-project"
}

resource "aws_instance" "webserver1" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.integrated_sg.id]
  subnet_id              = aws_subnet.IntSub1.id
  user_data              = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.integrated_sg.id]
  subnet_id              = aws_subnet.IntSub2.id
  user_data              = base64encode(file("userdata1.sh"))
}

# create alb
resource "aws_lb" "intergrated-elb" {
  name               = "integrated-elb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.integrated_sg.id]
  subnets            = [aws_subnet.IntSub1.id, aws_subnet.IntSub2.id]

  tags = {
    Name = "elb"
  }
}

resource "aws_lb_target_group" "IntergratedTG" {
  name     = "IntergratedTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.integrated-vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "IntergratedTG1" {
  target_group_arn = aws_lb_target_group.IntergratedTG.arn
  target_id        = aws_instance.webserver1.id
  port             = "80"
}

resource "aws_lb_target_group_attachment" "IntergratedTG2" {
  target_group_arn = aws_lb_target_group.IntergratedTG.arn
  target_id        = aws_instance.webserver2.id
  port             = "80"
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.intergrated-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.IntergratedTG.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb_target_group.IntergratedTG
}