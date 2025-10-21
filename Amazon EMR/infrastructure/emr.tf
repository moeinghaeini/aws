# Amazon EMR Cluster Configuration

# EMR Cluster
resource "aws_emr_cluster" "emr_cluster" {
  name          = "${local.name_prefix}-cluster"
  release_label = var.emr_release_label
  applications  = var.emr_applications

  ec2_attributes {
    subnet_id                         = aws_subnet.public_subnets[0].id
    emr_managed_master_security_group = aws_security_group.emr_master_sg.id
    emr_managed_slave_security_group  = aws_security_group.emr_worker_sg.id
    instance_profile                  = aws_iam_instance_profile.emr_instance_profile.arn
    key_name                          = aws_key_pair.emr_key.key_name
  }

  master_instance_group {
    instance_type = var.master_instance_type
    instance_count = 1
  }

  core_instance_group {
    instance_type  = var.worker_instance_type
    instance_count = var.worker_instance_count

    ebs_config {
      size                 = 100
      type                 = "gp3"
      volumes_per_instance = 1
    }
  }

  ebs_root_volume_size = 100

  log_uri = "s3://${aws_s3_bucket.emr_logs.bucket}/emr-logs/"

  service_role = aws_iam_role.emr_service_role.arn

  step {
    action_on_failure = "TERMINATE_CLUSTER"
    name              = "Setup Hadoop Debugging"

    hadoop_jar_step {
      jar  = "command-runner.jar"
      args = ["state-pusher-script"]
    }
  }

  # Bootstrap actions for additional configuration
  bootstrap_action {
    path = "s3://${aws_s3_bucket.emr_scripts.bucket}/bootstrap/install-python-packages.sh"
    name = "Install Python Packages"
    args = ["pip", "install", "boto3", "pandas", "numpy", "scikit-learn"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster"
  })

  # Enable termination protection for production
  termination_protection = var.environment == "prod" ? true : false

  # Auto-scaling configuration
  dynamic "auto_scaling_role" {
    for_each = var.enable_auto_scaling ? [1] : []
    content {
      auto_scaling_role = aws_iam_role.emr_autoscaling_role[0].arn
    }
  }

  depends_on = [
    aws_s3_bucket.emr_logs,
    aws_s3_bucket.emr_scripts,
    aws_iam_role.emr_service_role,
    aws_iam_instance_profile.emr_instance_profile
  ]
}

# EMR Managed Scaling Policy
resource "aws_emr_managed_scaling_policy" "emr_scaling_policy" {
  count      = var.enable_auto_scaling ? 1 : 0
  cluster_id = aws_emr_cluster.emr_cluster.id

  compute_limits {
    unit_type                       = "InstanceFleetUnits"
    minimum_capacity_units          = var.min_capacity
    maximum_capacity_units          = var.max_capacity
    maximum_on_demand_capacity_units = var.max_capacity
    maximum_core_capacity_units     = var.max_capacity
  }
}

# EMR Step for Data Processing Job
resource "aws_emr_step" "data_processing_step" {
  cluster_id     = aws_emr_cluster.emr_cluster.id
  name           = "Data Processing Job"
  action_on_failure = "CONTINUE"

  hadoop_jar_step {
    jar  = "command-runner.jar"
    args = [
      "spark-submit",
      "--deploy-mode", "cluster",
      "--class", "org.apache.spark.examples.SparkPi",
      "s3://${aws_s3_bucket.emr_scripts.bucket}/spark-examples.jar",
      "10"
    ]
  }
}

# CloudWatch Log Group for EMR
resource "aws_cloudwatch_log_group" "emr_log_group" {
  count             = var.enable_monitoring ? 1 : 0
  name              = "/aws/emr/${local.name_prefix}-cluster"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# CloudWatch Log Stream for EMR Master
resource "aws_cloudwatch_log_stream" "emr_master_log_stream" {
  count          = var.enable_monitoring ? 1 : 0
  name           = "master-node"
  log_group_name = aws_cloudwatch_log_group.emr_log_group[0].name
}

# CloudWatch Log Stream for EMR Workers
resource "aws_cloudwatch_log_stream" "emr_worker_log_stream" {
  count          = var.enable_monitoring ? 1 : 0
  name           = "worker-nodes"
  log_group_name = aws_cloudwatch_log_group.emr_log_group[0].name
}
