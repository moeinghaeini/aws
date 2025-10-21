# VPC Configuration for Monitoring Infrastructure
resource "aws_vpc" "monitoring_vpc" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "monitoring-vpc"
    Project = "monitoring-security"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "monitoring_igw" {
  vpc_id = aws_vpc.monitoring_vpc.id

  tags = {
    Name = "monitoring-igw"
    Project = "monitoring-security"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.monitoring_vpc.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "monitoring-public-subnet-1"
    Project = "monitoring-security"
    Type = "public"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.monitoring_vpc.id
  cidr_block              = "10.2.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "monitoring-public-subnet-2"
    Project = "monitoring-security"
    Type = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.monitoring_vpc.id
  cidr_block        = "10.2.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "monitoring-private-subnet-1"
    Project = "monitoring-security"
    Type = "private"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.monitoring_vpc.id
  cidr_block        = "10.2.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "monitoring-private-subnet-2"
    Project = "monitoring-security"
    Type = "private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.monitoring_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.monitoring_igw.id
  }

  tags = {
    Name = "monitoring-public-rt"
    Project = "monitoring-security"
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
