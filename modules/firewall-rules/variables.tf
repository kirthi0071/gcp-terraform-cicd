variable "vpc_name" {
  description = "Name of the VPC (used for firewall rule naming)"
  type        = string
}

variable "vpc_self_link" {
  description = "Self link of the VPC network"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR range of the subnet, used for internal traffic rule"
  type        = string
}

variable "ssh_source_ranges" {
  description = "Allowed source IP ranges for SSH access"
  type        = list(string)
  
}
