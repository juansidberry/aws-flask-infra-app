terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { 
    Name = "${var.name}-vpc" 
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = { 
    Name = "${var.name}-igw" 
  }
}

resource "aws_subnet" "public" {
  for_each = toset(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = element(var.azs, index(var.public_subnet_cidrs, each.value))
  tags = { 
    Name = "${var.name}-public-${substr(replace(each.value, ".", "-", ),8,4)}" 
  }
}

resource "aws_subnet" "private" {
  for_each = toset(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = element(var.azs, index(var.private_subnet_cidrs, each.value))
  tags = { 
    Name = "${var.name}-private-${substr(replace(each.value, ".", "-", ),8,4)}" 
  }
}

resource "aws_eip" "nat" { 
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  tags = { 
    Name = "${var.name}-nat" 
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route { 
    cidr_block = "0.0.0.0/0" 
    gateway_id = aws_internet_gateway.igw.id 
  }
  tags = { 
    Name = "${var.name}-public-rt" 
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route { 
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id 
  }
  tags = { 
    Name = "${var.name}-private-rt" 
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# NACLs – restrictive example (allow HTTP/HTTPS in public, ephemeral out in private)
resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.public : s.id]
  ingress { 
    rule_no=100 
    protocol="tcp" 
    action="allow" 
    cidr_block="0.0.0.0/0" 
    from_port=80  
    to_port=80 
  }
  ingress { 
    rule_no=110 
    protocol="tcp" 
    action="allow" 
    cidr_block="0.0.0.0/0" 
    from_port=443 
    to_port=443 
  }
  egress { 
    rule_no=100 
    protocol="-1"   
    action="allow" 
    cidr_block="0.0.0.0/0" 
    from_port=0   
    to_port=0 
  }
  tags = { 
    Name = "${var.name}-public-nacl" 
  }
}

resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.private : s.id]
  # allow ephemeral outbound and established return; block inbound by default
  egress  { 
    rule_no=100 
    protocol="-1" 
    action="allow" 
    cidr_block="0.0.0.0/0" 
    from_port=0 
    to_port=0 
  }
  tags = { 
    Name = "${var.name}-private-nacl" 
  }
}

output "vpc_id"                { value = aws_vpc.this.id }
output "public_subnet_ids"     { value = [for s in aws_subnet.public  : s.id] }
output "private_subnet_ids"    { value = [for s in aws_subnet.private : s.id] }