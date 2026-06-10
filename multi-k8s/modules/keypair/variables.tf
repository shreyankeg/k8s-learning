variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
}

variable "keys_dir" {
  description = "Local directory path where the private key .pem file will be saved"
  type        = string
}
