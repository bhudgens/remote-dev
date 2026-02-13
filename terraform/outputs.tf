output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.remote_dev.id
}

output "public_ip" {
  description = "Public IP (for initial reference — primary access is via NetBird)"
  value       = aws_instance.remote_dev.public_ip
}

output "instance_state" {
  description = "Current instance state"
  value       = aws_instance.remote_dev.instance_state
}

output "ami_id" {
  description = "AMI used for the instance"
  value       = data.aws_ami.ubuntu.id
}

output "ami_name" {
  description = "AMI name"
  value       = data.aws_ami.ubuntu.name
}
