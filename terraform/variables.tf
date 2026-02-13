variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Name tag of the VPC to deploy into"
  type        = string
  default     = "cloud-development-vpc"
}

variable "subnet_name" {
  description = "Name tag of the subnet to deploy into"
  type        = string
  default     = "cloud-development-public"
}

variable "instance_name" {
  description = "Name for the instance (used for EC2 tag and hostname)"
  type        = string
  default     = "cloud-development"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "netbird_setup_key" {
  description = "NetBird setup key for peer registration"
  type        = string
  sensitive   = true
}

variable "netbird_management_url" {
  description = "NetBird management server URL"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name for emergency access"
  type        = string
  default     = "remote-dev-key"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed for inbound SSH (empty = no inbound SSH)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project = "remote-dev"
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}
