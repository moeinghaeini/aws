# EC2 Key Pair for EMR Cluster SSH Access

# Generate RSA key pair for EMR cluster access
resource "tls_private_key" "emr_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# AWS Key Pair
resource "aws_key_pair" "emr_key" {
  key_name   = "${local.name_prefix}-key"
  public_key = tls_private_key.emr_key.public_key_openssh

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-key"
  })
}

# Save private key to local file
resource "local_file" "emr_private_key" {
  content  = tls_private_key.emr_key.private_key_pem
  filename = "${path.module}/../keys/emr_private_key.pem"
  file_permission = "0400"
}

# Save public key to local file
resource "local_file" "emr_public_key" {
  content  = tls_private_key.emr_key.public_key_openssh
  filename = "${path.module}/../keys/emr_public_key.pem"
  file_permission = "0644"
}
