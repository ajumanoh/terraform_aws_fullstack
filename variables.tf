variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Region name where EC2 instance should be created"

  validation {
    # regex(...) fails if the region is not with in us
    condition     = can(regex("^us-", var.region))
    error_message = "You cannot choose a region out of USA."
  }
}

variable "subnet_count" {
  default = 2
}

variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnets" {
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "keypair" {
  type        = string
  default     = "ajumano"
  description = "Keypair to ssh in to EC2 instance"
}

variable "environment" {
  type        = string
  default     = "development"
  description = "environment"
}
