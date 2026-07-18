variable "vm_name" {
  description = "Name of the VM instance"
  type        = string
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-micro"
}

variable "zone" {
  description = "GCP zone for the instance"
  type        = string
}

variable "image" {
  description = "Boot disk image"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "subnet_self_link" {
  description = "Self link of the subnet to attach the VM to"
  type        = string
}

variable "network_tags" {
  description = "Network tags for firewall targeting"
  type        = list(string)
  default     = ["ssh", "web"]
}

variable "creator" {
  description = "Label identifying who created this resource"
  type        = string
  default     = "kirthi"
}

variable "environment" {
  description = "Environment label (dev/staging/prod)"
  type        = string
  default     = "dev"
}