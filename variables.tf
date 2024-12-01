variable "location" {
  description = "Default location of all resources for this exercise"
  default     = "eastus2"
}

variable "default_tags" {
  description = "A map of default tags to apply to resources."
  type        = map(string)
  default = {
    TimePeriod = "Nov2024"
    Project    = "Azure LB VM Demo"
  }
}

variable "vmname-prefix" {
  description = "Prefix for the Web VMs for this exercise"
  default     = "alb-webvm"
}

variable "vm-admin" {
  description = "The VM admin account name"
  default     = "romulus"
}

variable "vm-admin-pw" {
  description = "Credentials for the admin account"
  sensitive   = true
}

variable "vm_address_prefixes" {
  default = ["10.253.21.0/24", "10.253.22.0/24"]
}

variable "vm_priv_ips" {
  default = ["10.253.21.10", "10.253.22.10"]
}

variable "vm_zones" {
  type    = list(string)
  default = ["1", "2"] # Zone 1 for the first VM, Zone 2 for the second VM
}