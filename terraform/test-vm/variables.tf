variable "rg" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "username" {
  description = "Admin username for VM"
  type        = string
}

variable "password" {
  description = "Admin password for VM"
  type        = string
  sensitive   = true
}