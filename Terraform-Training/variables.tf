variable "ami" {
  type        = string
  default     = "ami-05fa00d4c63e32376"
  description = "Amazon Machine Image"
}

variable "instance_type" {
  type = string
  default = "t2.micro"
  description = "Instance Type for EC2 Instances"
}

variable "db_username" {
  type        = string
  default     = "YOUR USERNAME"
  description = "DB Username"
}

variable "db_password" {
  type        = string
  default     = "YOUR PASSWORD"
  description = "DB Password"
}
