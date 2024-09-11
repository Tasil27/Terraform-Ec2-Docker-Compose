provider "aws" {
  region = "eu-central-1"
}

# VPC
resource "aws_vpc" "main_vpc_prod" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "main-prod-vpc"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "main_igw_prod" {
    vpc_id = aws_vpc.main_vpc_prod.id

    tags = {
        Name = "main-prod-igw"
    }
}

# Public subnet
resource "aws_subnet" "main_public_subnet_a_prod" {
    vpc_id = aws_vpc.main_vpc_prod.id
    cidr_block = "10.0.0.0/20"
    availability_zone = "eu-central-1a"
    map_public_ip_on_launch = true

    tags = {
        Name = "main-prod-public-subnet-a"
    }
}

# Private subnet
resource "aws_subnet" "main_private_subnet_a_prod" {
    vpc_id = aws_vpc.main_vpc_prod.id
    cidr_block = "10.0.128.0/20"
    availability_zone = "eu-central-1a"

    tags = {
        Name = "main-prod-private-subnet-a"
    }
}

# Public Route Table
resource "aws_route_table" "public_rtb_prod" {
    vpc_id = aws_vpc.main_vpc_prod.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main_igw_prod.id
    }

    tags = {
        Name = "main-prod-vpc-public-route-table"
    }
}

# Public Subnet to Public Route Table Association
resource "aws_route_table_association" "public_rtb_subnet_assoc_prod" {
    subnet_id = aws_subnet.main_public_subnet_a_prod.id
    route_table_id = aws_route_table.public_rtb_prod.id
}

# Security Group
resource "aws_security_group" "web_sg_prod" {
    vpc_id = aws_vpc.main_vpc_prod.id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
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
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "web-security-group-prod"
    }
}

# EC2 Instance - Web Server
resource "aws_instance" "web_server_prod" {
    ami                    = "ami-0de02246788e4a354" # Stelle sicher, dass dies das Amazon Linux 2023 AMI ist
    instance_type          = "t2.micro"
    subnet_id              = aws_subnet.main_public_subnet_a_prod.id
    vpc_security_group_ids = [aws_security_group.web_sg_prod.id]

    user_data = <<-EOF
                #!/bin/bash
                # Update the system
                dnf update -y

                # Install Docker
                dnf install -y docker
                systemctl start docker
                systemctl enable docker
                usermod -aG docker ec2-user

                # Install Docker Compose
                curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose

                # Create a directory for the app
                mkdir /home/ec2-user/feedback-app
                cd /home/ec2-user/feedback-app

                # Create Docker-Compose file
                cat <<EOL > docker-compose.yml
                version: '3'
                services:
                  feedback-app:
                    image: tasil/feedback-app:latest
                    ports:
                      - "80:80"
                EOL

                # Start Docker-Compose
                docker-compose up -d
                EOF

    tags = {
        Name = "web-server-prod"
    }
}

# Outputs
output "instance_public_ip" {
    description = "The public IP of the EC2 instance"
    value       = aws_instance.web_server_prod.public_ip
}
