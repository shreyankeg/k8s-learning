variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 6
}

variable "ami_id" {
  description = "AMI ID for the EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to place the instances and security group in"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs to distribute instances across (round-robin)"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR — all traffic within this range is allowed between nodes (required for K8s)"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to reach port 22 and the Kubernetes API (6443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_name_prefix" {
  description = "Prefix for the Name tag on each instance"
  type        = string
  default     = "ec2-instance"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
