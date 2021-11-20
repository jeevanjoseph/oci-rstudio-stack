variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "region" {}
# variable "fingerprint" {}
# variable "private_key_path" {}
# variable "user_ocid" {}
variable "availability_domain_name" {
  default = null
}


## Networking

variable "vcn" {
  default = "theia-vcn"
}

variable "vcn_cidr" {
  description = "VCN's CIDR IP Block"
  default     = "10.0.0.0/16"
}

## Instance

variable "node_shape" {
  default     = "VM.Standard.E2.1"
}

variable "label_prefix" {
  default     = ""
}

variable "instance_os" {
  description = "Operating system."
  default     = "Oracle Linux"
}

variable "linux_os_version" {
  description = "Operating system version."
  default     = "7.9"
}

variable "generate_public_ssh_key" {
  default = true
}
variable "public_ssh_key" {
  default = ""
}

# RStudio

variable "rstudio_user" {
  description = "The username that RStudio uses to connect to the MySQL database."
  default     = "admin"  
}

variable "rstudio_password" {
  description = "Password for RStudio to connect to the MySQL database."
  default     = "MyPassw0rd!"  
}
