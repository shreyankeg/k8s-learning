locals {
  half = var.instance_count / 2
  instance_names = [
    for i in range(var.instance_count) :
    i < local.half
    ? "${var.instance_name_prefix}-master-${i + 1}"
    : "${var.instance_name_prefix}-slave-${i - local.half + 1}"
  ]
}

resource "aws_security_group" "this" {
  name        = "${var.instance_name_prefix}-sg"
  description = "SSH + Kubernetes API external; all traffic within VPC"
  vpc_id      = var.vpc_id

  # SSH access from user-defined CIDRs
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  # Kubernetes API server — allows kubectl from user-defined CIDRs
  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  # All inter-node traffic within the VPC (kubelet, etcd, CNI, RKE2 join port 9345, etc.)
  ingress {
    description = "All intra-VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({ Name = "${var.instance_name_prefix}-sg" }, var.tags)
}

resource "aws_instance" "this" {
  count = var.instance_count

  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = element(var.subnet_ids, count.index)
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = true

  tags = merge(
    { Name = local.instance_names[count.index] },
    var.tags
  )
}
