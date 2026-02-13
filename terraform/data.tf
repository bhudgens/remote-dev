# Look up existing VPC by Name tag
data "aws_vpc" "netbird" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Look up existing subnet by Name tag within the VPC
data "aws_subnet" "netbird" {
  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.netbird.id]
  }
}

# Latest Ubuntu 24.04 LTS AMI (Canonical, amd64, hvm, ebs)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
