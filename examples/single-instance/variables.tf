variable "tenancy_ocid" {
}

variable "user_ocid" {
}

variable "fingerprint" {
}

variable "private_key_path" {
}

variable "region" {
  description = "The region"
}

variable "compartment_id" {
  description = "compartment id where to create all resources"
  type        = string
  # no default value, asking user to explicitly set this variable's value. see codingconventions.adoc
}

variable "label_prefix" {
  description = "a string that will be prepended to all resources"
  type        = string
  default     = "none"
}


variable "admin_ssh_pub_key" {
  description = "ssh public key for admin"
}

variable "enable_password" {
  type        = string
  description = "enable password for ASA zero day config"
}

variable "day_0_config" {
  description = "Render a startup script with a template."
  default     = ""
}
variable "mgmt_network" {
  type        = string
  description = "management network name"
  default     = ""
}

variable "inside_network" {
  type        = string
  description = "inside network name"
  default     = ""
}
variable "outside_network" {
  type        = string
  description = "outside network name"
  default     = ""
}

variable "dmz1_network" {
  type        = string
  description = "dmz1 network name"
  default     = ""
}

variable "dmz2_network" {
  type        = string
  description = "dmz2 network name"
  default     = "vpc-dmz2"
}

variable "vm_ads_number" {
  type        = list(number)
  default     = [1]
  description = "The Availability Domain Number for vm, OCI Availability Domains: 1,2,3  (subject to region availability)"
}

variable "num_instances" {
  description = "Number of instances to create. This value is ignored if static_ips is provided."
  type        = number
  default     = 1
}


variable "networks" {
  type        = list(object({ name = string, vcn_cidr = string, subnet_cidr = string, private_ip = list(string), external_ip = bool }))
  description = "a list of VPC"
  default     = []
}

## networks (flattened)
variable "network_1_name" {

}

variable "network_1_vcn_cidr" {

}

variable "network_1_subnet_cidr" {

}

variable "network_1_private_ip" {
  type = list(string)
}


variable "network_1_external_ip" {

  type    = bool
  default = false
}

variable "network_2_name" {

}

variable "network_2_vcn_cidr" {

}

variable "network_2_subnet_cidr" {

}

variable "network_2_private_ip" {
  type = list(string)
}


variable "network_2_external_ip" {

  type    = bool
  default = false
}

variable "network_3_name" {

}

variable "network_3_vcn_cidr" {

}

variable "network_3_subnet_cidr" {

}

variable "network_3_private_ip" {
  type = list(string)
}


variable "network_3_external_ip" {

  type    = bool
  default = false
}
variable "network_4_name" {

}

variable "network_4_vcn_cidr" {

}

variable "network_4_subnet_cidr" {

}

variable "network_4_private_ip" {
  type = list(string)
}


variable "network_4_external_ip" {

  type    = bool
  default = false
}