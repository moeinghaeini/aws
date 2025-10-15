# VPC Configuration for GlobalMart
resource "aws_vpc" "globalmart_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "globalmart-vpc"
    Project = "globalmart-cicd"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "globalmart_igw" {
  vpc_id = aws_vpc.globalmart_vpc.id

  tags = {
    Name = "globalmart-igw"
    Project = "globalmart-cicd"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.globalmart_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "globalmart-public-subnet-1"
    Project = "globalmart-cicd"
    Type = "public"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.globalmart_vpc.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "globalmart-public-subnet-2"
    Project = "globalmart-cicd"
    Type = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.globalmart_vpc.id
  cidr_block        = "10.1.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "globalmart-private-subnet-1"
    Project = "globalmart-cicd"
    Type = "private"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.globalmart_vpc.id
  cidr_block        = "10.1.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "globalmart-private-subnet-2"
    Project = "globalmart-cicd"
    Type = "private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.globalmart_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.globalmart_igw.id
  }

  tags = {
    Name = "globalmart-public-rt"
    Project = "globalmart-cicd"
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
