output "instance_ids" {
  description = "List of IDs of the EC2 instances"
  value       = aws_instance.this[*].id
}

output "public_ips" {
  description = "List of public IP addresses of the EC2 instances"
  value       = aws_instance.this[*].public_ip
}

output "private_ips" {
  description = "List of private IP addresses of the EC2 instances"
  value       = aws_instance.this[*].private_ip
}

output "instance_arns" {
  description = "List of ARNs of the EC2 instances"
  value       = aws_instance.this[*].arn
}

output "security_group_id" {
  description = "ID of the security group attached to the instances"
  value       = aws_security_group.this.id
}
