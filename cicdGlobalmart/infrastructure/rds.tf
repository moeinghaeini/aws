# RDS Subnet Group
resource "aws_db_subnet_group" "globalmart_db_subnet_group" {
  name       = "globalmart-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "globalmart-db-subnet-group"
    Project = "globalmart-cicd"
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "globalmart_db_params" {
  family = "mysql8.0"
  name   = "globalmart-db-params"

  parameter {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}"
  }

  tags = {
    Name = "globalmart-db-params"
    Project = "globalmart-cicd"
  }
}

# RDS Instance
resource "aws_db_instance" "globalmart_db" {
  identifier = "globalmart-db"
  
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true
  
  db_name  = "globalmart"
  username = "admin"
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.globalmart_db_subnet_group.name
  parameter_group_name   = aws_db_parameter_group.globalmart_db_params.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = {
    Name = "globalmart-db"
    Project = "globalmart-cicd"
  }
}

# Variables
variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
  sensitive   = true
  default     = "GlobalMart2024!"
}

# Outputs
output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.globalmart_db.endpoint
  sensitive   = true
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.globalmart_db.port
}
