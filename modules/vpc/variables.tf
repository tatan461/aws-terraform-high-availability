variable "environment" {
  type        = string
  description = "Deployment environment name"
}

variable "vpc_cidr" {
  type        = string
  description = "Base CIDR block for the VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
}
