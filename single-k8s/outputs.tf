# ── VPC ───────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the 3 public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the 3 private subnets"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = module.vpc.nat_gateway_public_ip
}

# ── Key pair ──────────────────────────────────────────────────────────────────

output "key_name" {
  description = "Name of the AWS key pair"
  value       = module.keypair.key_name
}

output "private_key_path" {
  description = "Local path to the private key .pem file"
  value       = module.keypair.private_key_path
}

# ── EC2 instances ─────────────────────────────────────────────────────────────

output "instance_ids" {
  description = "IDs of all 6 EC2 instances (2 masters + 4 agents)"
  value       = module.ec2_instances.instance_ids
}

output "public_ips" {
  description = "Public IPs of all 6 EC2 instances"
  value       = module.ec2_instances.public_ips
}

output "private_ips" {
  description = "Private IPs of all 6 EC2 instances"
  value       = module.ec2_instances.private_ips
}

output "security_group_id" {
  description = "ID of the EC2 security group"
  value       = module.ec2_instances.security_group_id
}
