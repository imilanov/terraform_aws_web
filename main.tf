provider "aws" {
  region = "us-east-1"
}


#Web server instance
resource "aws_instance" "web-server" {
  ami               = "ami-090fa75af13c156b4"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1"
  key_name          = "sysops"
  security_groups   = ["web_traffic"]
# set netowrk interface
  # Server install
  user_data = <<-EOF
#! /bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
echo "The page was created by the user data" | sudo tee /var/www/html/index.html
EOF

  tags = {
    Name = "web-server-im"
  }
}

#Create VPC
resource "aws_vpc" "ivan-web-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "web-vpc-im"
  }
}
#Create Subnet
resource "aws_subnet" "ivan-web-vpc-sub1" {
  vpc_id            = aws_vpc.ivan-web-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1"

  tags = {
    Name = "web-subnet-im"
  }
}
#IGW
resource "aws_internet_gateway" "web-ig" {
  vpc_id = aws_vpc.ivan-web-vpc.id

  tags = {
    Name = "Web IGW"
  }
}

#Route Table
resource "aws_route_table" "web-route-table" {
  vpc_id = aws_vpc.ivan-web-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web-ig.id
  }

  tags = {
    Name = "web-route-table"
  }
}


#Route Table Associate
resource "aws_route_table_association" "rt-associate" {
  subnet_id      = aws_subnet.ivan-web-vpc-sub1.id
  route_table_id = aws_route_table.web-route-table.id
}




#Security Groups
resource "aws_security_group" "web_traffic" {
  name        = "allow_web"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.ivan-web-vpc.id

  ingress {
    description = "SSL from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Network interface
resource "aws_network_interface" "netowrk-web-interface" {
  subnet_id       = aws_subnet.ivan-web-vpc-sub1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.web_traffic.id]

  attachment {
    instance     = aws_instance.web-server.id
    device_index = 1
  }
}


#Elastic IP
resource "aws_eip" "elastic_ip"{ 

  instance = aws_instance.web-server.id
  vpc      = true
  depends_on = [aws_internet_gateway.web-ig, aws_instance.web-server]
}

output "server_public_ip" {
  value = aws_eip.elastic_ip.public_ip
}

# terraform Files yt https://www.youtube.com/watch?v=SLB_c_ayRMo
#https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_file
#https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_file