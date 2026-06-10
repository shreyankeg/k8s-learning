# ── AWS credentials ──────────────────────────────────────────────────────────

variable "aws_access_key" {
  description = "AWS access key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

# ── VPC ───────────────────────────────────────────────────────────────────────

variable "vpc_name" {
  description = "Name prefix applied to all VPC resources"
  type        = string
  default     = "main"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the 3 public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the 3 private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# ── SSH key pair ──────────────────────────────────────────────────────────────

variable "key_name" {
  description = "Name of the AWS key pair (private key saved to keys/<key_name>.pem)"
  type        = string
  default     = "ec2-key"
}

# ── EC2 instances ─────────────────────────────────────────────────────────────

variable "ami_id" {
  description = "AMI ID for the EC2 instances — must match the selected region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3a.medium"
}

variable "instance_name_prefix" {
  description = "Prefix applied to the Name tag of each EC2 instance"
  type        = string
  default     = "ec2-node"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed SSH (port 22) access to the instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── Shared tags ───────────────────────────────────────────────────────────────

variable "tags" {
  description = "Additional tags applied to every resource"
  type        = map(string)
  default     = {}
}
