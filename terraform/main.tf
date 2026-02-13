# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "remote_dev" {
  name_prefix = "remote-dev-"
  description = "Remote dev instance - egress only, no inbound by default"
  vpc_id      = data.aws_vpc.netbird.id

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.remote_dev.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Optional: inbound SSH from specified CIDRs
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.allowed_ssh_cidr)

  security_group_id = aws_security_group.remote_dev.id
  description       = "SSH from ${each.value}"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

# ── EC2 Instance ─────────────────────────────────────────────────────────────

resource "aws_instance" "remote_dev" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = data.aws_subnet.netbird.id

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.remote_dev.id]

  user_data = templatefile("${path.module}/user-data.sh.tpl", {
    setup_key      = var.netbird_setup_key
    management_url = var.netbird_management_url
    hostname       = var.instance_name
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}
