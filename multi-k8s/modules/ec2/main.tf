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

# IAM role attached to every node so in-cluster workloads (external-dns)
# can manage Route 53 records via the instance profile — no static AWS keys.
resource "aws_iam_role" "node" {
  name = "${var.instance_name_prefix}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "route53_dns" {
  name = "${var.instance_name_prefix}-route53-dns"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.instance_name_prefix}-node-profile"
  role = aws_iam_role.node.name
  tags = var.tags
}

resource "aws_instance" "this" {
  count = var.instance_count

  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = element(var.subnet_ids, count.index)
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.node.name

  # Hop limit 2 lets pods (behind the CNI overlay) reach the instance
  # metadata service to pick up the node role's credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(
    { Name = local.instance_names[count.index] },
    var.tags
  )
}
