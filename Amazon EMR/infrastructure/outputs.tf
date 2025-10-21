# Outputs for Amazon EMR Big Data Platform

output "emr_cluster_id" {
  description = "EMR Cluster ID"
  value       = aws_emr_cluster.emr_cluster.id
}

output "emr_cluster_name" {
  description = "EMR Cluster Name"
  value       = aws_emr_cluster.emr_cluster.name
}

output "emr_cluster_master_public_dns" {
  description = "EMR Master Node Public DNS"
  value       = aws_emr_cluster.emr_cluster.master_public_dns
}

output "emr_cluster_master_public_ip" {
  description = "EMR Master Node Public IP"
  value       = aws_emr_cluster.emr_cluster.master_public_ip
}

output "data_lake_bucket_name" {
  description = "S3 Data Lake Bucket Name"
  value       = aws_s3_bucket.emr_data_lake.bucket
}

output "data_lake_bucket_arn" {
  description = "S3 Data Lake Bucket ARN"
  value       = aws_s3_bucket.emr_data_lake.arn
}

output "scripts_bucket_name" {
  description = "S3 Scripts Bucket Name"
  value       = aws_s3_bucket.emr_scripts.bucket
}

output "scripts_bucket_arn" {
  description = "S3 Scripts Bucket ARN"
  value       = aws_s3_bucket.emr_scripts.arn
}

output "logs_bucket_name" {
  description = "S3 Logs Bucket Name"
  value       = aws_s3_bucket.emr_logs.bucket
}

output "logs_bucket_arn" {
  description = "S3 Logs Bucket ARN"
  value       = aws_s3_bucket.emr_logs.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.emr_vpc.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR Block"
  value       = aws_vpc.emr_vpc.cidr_block
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = aws_subnet.private_subnets[*].id
}

output "emr_service_role_arn" {
  description = "EMR Service Role ARN"
  value       = aws_iam_role.emr_service_role.arn
}

output "emr_instance_profile_arn" {
  description = "EMR Instance Profile ARN"
  value       = aws_iam_instance_profile.emr_instance_profile.arn
}

output "ssh_private_key_path" {
  description = "Path to SSH Private Key"
  value       = local_file.emr_private_key.filename
}

output "ssh_public_key_path" {
  description = "Path to SSH Public Key"
  value       = local_file.emr_public_key.filename
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group Name"
  value       = var.enable_monitoring ? aws_cloudwatch_log_group.emr_log_group[0].name : null
}

output "emr_managed_scaling_policy_id" {
  description = "EMR Managed Scaling Policy ID"
  value       = var.enable_auto_scaling ? aws_emr_managed_scaling_policy.emr_scaling_policy[0].id : null
}

# Connection information for SSH access
output "ssh_connection_command" {
  description = "SSH command to connect to EMR master node"
  value       = "ssh -i ${local_file.emr_private_key.filename} hadoop@${aws_emr_cluster.emr_cluster.master_public_dns}"
}

# YARN Resource Manager URL
output "yarn_resource_manager_url" {
  description = "YARN Resource Manager URL"
  value       = "http://${aws_emr_cluster.emr_cluster.master_public_dns}:8088"
}

# Spark History Server URL
output "spark_history_server_url" {
  description = "Spark History Server URL"
  value       = "http://${aws_emr_cluster.emr_cluster.master_public_dns}:18080"
}

# Hue Web Interface URL
output "hue_web_interface_url" {
  description = "Hue Web Interface URL"
  value       = "http://${aws_emr_cluster.emr_cluster.master_public_dns}:8888"
}
