# Create new AWS Virtual Private Cloud
# Secure and powerful way to build and manage a virtual network within AWS ecosystem
# Isolated Network: populated by my own AWS resources, and logically isolated from other virtual networks in AWS cloud
# Custom IP Address Range
# Controlled Network Environment: Complete control over virtual networking environment, including selection of IP address range, creation of subnets, route tables and network gateways
resource "aws_vpc" "rancher_vpc" {
  # IP Address range (10.0.0.0 -> 10.0.255.255)
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.prefix}-rancher-vpc"
    Creator = var.creator
  }
}

# Create an internet gateway for the VPC to allow communication between instances and the internet
resource "aws_internet_gateway" "rancher_gateway" {
  vpc_id = aws_vpc.rancher_vpc.id

  tags = {
    Name = "${var.prefix}-rancher-gateway"
    Creator = var.creator
  }
}

# Create a subnet within the VPC using a CIDR block
resource "aws_subnet" "rancher_subnet" {
  vpc_id = aws_vpc.rancher_vpc.id

  # Subenet IP address range from 10.0.0.0 -> 10.0.0.255
  # CIDR (Classless Inter-Domain Routing) block -> Method for allocating IP addresses and IP routing
  cidr_block        = "10.0.0.0/24"
  availability_zone = var.aws_zone

  tags = {
    Name = "${var.prefix}-rancher-subnet"
    Creator = var.creator
  }
}

# Create a route table
resource "aws_route_table" "rancher_route_table" {
  vpc_id = aws_vpc.rancher_vpc.id

  # single route
  # Direct all traffic (0.0.0.0/0) to the internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rancher_gateway.id
  }

  tags = {
    Name = "${var.prefix}-rancher-route-table"
    Creator = var.creator
  }
}

# Associate Subnet with route table
# All instances created in the subnet will adhere to the routing rules defined in the route table
# Wich in this case, includes access to the internet via the internet gateway
resource "aws_route_table_association" "rancher_route_table_association" {
  subnet_id      = aws_subnet.rancher_subnet.id
  route_table_id = aws_route_table.rancher_route_table.id
}

# Security group to allow all traffic
resource "aws_security_group" "rancher_sg_allowall" {
  name        = "${var.prefix}-rancher-allowall"
  description = "Rancher quickstart - allow all traffic"
  vpc_id      = aws_vpc.rancher_vpc.id

  # Inbound rules: all protocols from all IP addresses to all ports of incoming traffic
  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules: same thing
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-rancher-sec-group"
    Creator = var.creator
  }
}

#---------------------------------------------------------------------------------------------------------
# SSH key management
# Create a new RSA private key using the `tls` provider
resource "tls_private_key" "global_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Save the previously generated private RSA key to a file on my local system
resource "local_sensitive_file" "ssh_private_key_pem" {
  filename        = "${path.module}/certs/id_rsa"
  content         = tls_private_key.global_key.private_key_pem
  file_permission = "0600"
}

# Save the previously corresponding generated public key to a file on my local system
resource "local_file" "ssh_public_key_openssh" {
  filename = "${path.module}/certs/id_rsa.pub"
  content  = tls_private_key.global_key.public_key_openssh
}
# ${path.module} = directory of the current Terraform module where the configuration is placed.
#------------------------------------------------------------------------------------------------

# Upload the generated and saved public key to AWS
# to create an AWS Key Pair that can be used for SSH access to EC2 instances.
resource "aws_key_pair" "nick_key_pair" {
  key_name_prefix = "${var.prefix}-key-pair"
  public_key      = tls_private_key.global_key.public_key_openssh
}
