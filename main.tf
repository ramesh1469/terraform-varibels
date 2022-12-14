resource "aws_vpc" "ntier-vpc" {
  cidr_block = var.vpc_subnets.vpc_cidr_block
  tags = {
    "Name" = var.vpc_subnets.vpc_tags
  }
}

resource "aws_subnet" "aws_subnet" {
  count             = 3
  vpc_id            = aws_vpc.ntier-vpc.id
  cidr_block        = var.vpc_subnets.subnets_cidr_block[count.index]
  availability_zone = var.vpc_subnets.subnet_zone[count.index]
  tags = {
    "Name" = var.vpc_subnets.subnet_tags[count.index]
  }
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.ntier-vpc.id
  cidr_block        = var.vpc_subnets.private_subnet_id[count.index]
  availability_zone = var.vpc_subnets.subnet_zone[count.index]
  tags = {
    "Name" = var.vpc_subnets.subnet_tags[3+count.index]
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ntier-vpc.id
  tags = {
    "Name" = "igw_vpc"
  }
  depends_on = [
    aws_vpc.ntier-vpc
  ]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.ntier-vpc.id
  route {
    cidr_block = var.public_route_table.route_cidr
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    "Name" = var.public_route_table.route_tags
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.ntier-vpc.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_route_table.subnet_id)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.aws_subnet[count.index].id
  depends_on = [
    aws_subnet.aws_subnet
  ]
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
  depends_on = [
    aws_subnet.private
  ]
}

resource "aws_security_group" "allow" {
  name   = "allow"
  vpc_id = aws_vpc.ntier-vpc.id
  ingress {
    description = "TLS from VPC"
    from_port   = var.security_group.from_port
    to_port     = var.security_group.to_port
    protocol    = var.security_group.protocol
    cidr_blocks = [var.security_group.cidr_block]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "web" {
  ami                         = var.aws_instance.ami
  instance_type               = var.aws_instance.instance_type
  subnet_id                   = aws_subnet.aws_subnet[0].id
  vpc_security_group_ids      = [aws_security_group.allow.id]
  associate_public_ip_address = var.aws_instance.associate_public_ip_address
  key_name                    = var.aws_instance.key_name
  tags = {
    "Name" = var.aws_instance.tags
  }
  depends_on = [
    aws_vpc.ntier-vpc
  ]
}
  resource "null_resource" "triggers"{
    triggers = {
      running_number = var.name_trigger
    }
  
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.web.public_ip
    }
    inline = [
      "sudo apt-get update",
      "sudo apt install nginx -y"
    ]
  
  }
}

resource "aws_instance" "app" {
  ami                         = var.aws_instance.ami
  instance_type               = var.aws_instance.instance_type
  subnet_id                   = aws_subnet.aws_subnet[1].id
  vpc_security_group_ids      = [aws_security_group.allow.id]
  associate_public_ip_address = var.aws_instance.associate_public_ip_address
  key_name                    = var.aws_instance.key_name
  
  depends_on = [
    aws_vpc.ntier-vpc
  ]
}
  resource "null_resource" "trigger"{
    triggers = {
      running_number = var.name_trigger
    }
  
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = aws_instance.app.public_ip
    }
    inline = [
      "sudo apt-get update",
      "sudo apt install apache2  -y"
    ]
  
  }
}
# Creating Network load balancer
resource "aws_lb" "my_loadlb" {
    name                         = "networkload"
    internal                     = false
    load_balancer_type           = "network"
    subnets                      = [aws_subnet.aws_subnet[0].id]
    ip_address_type              = "ipv4"
    enable_deletion_protection   = false
    depends_on = [
      aws_lb_target_group.awstgt
    ]
}

# Creating Target group for load balancer
resource "aws_lb_target_group" "awstgt" {
    name                    = "tgtgroup"
    port                    = 80
    protocol                = "TCP"
    target_type             = "instance"
    ip_address_type         = "ipv4"
    vpc_id                  = aws_vpc.ntier-vpc.id
    health_check {
       port                 = 80
       protocol             = "TCP"
       healthy_threshold    = 3
       interval             = 10
    }
    depends_on = [
      aws_instance.web
    ]
}

# Creating Listner Group
resource "aws_lb_listener" "awslistener" {
    load_balancer_arn       = aws_lb.my_loadlb.arn
    port                    = 80
    protocol                = "TCP"
    default_action {
      type                  = "forward"
      target_group_arn      = aws_instance.web.id
    }
    depends_on = [
      aws_lb_target_group.awstgt
    ]
}

# target_group_attachment to listner
resource "aws_lb_target_group_attachment" "attach" {
    count                   = 2
    target_group_arn        = aws_lb_target_group.awstgt.arn
    target_id               = aws_instance.web.id
    port                    = 80
    depends_on = [
     aws_instance.app
    ]
}