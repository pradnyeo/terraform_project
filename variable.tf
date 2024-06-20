variable "ami_id" {
  description = "AMI for Ec2 machine"
  type        = string
  default     = "ami-06b72b3b2a773be2b"
}
variable "instance_type" {
  description = "Instance_type for EC2"
  type        = string
  default     = "t2.medium"
}