variable "region" {
  type = string

}

variable "vpc_subnets" {
  type = object({
    vpc_cidr_block     = string
    vpc_tags           = string
    subnets_cidr_block = list(string)
    subnet_zone        = list(string)
    subnet_tags        = list(string)
    private_subnet_id  = list(string)
  })
  default = {
    subnet_zone        = ["us-east2a", "us-easte-2b", "us-east-2c", "us-east2a", "us-easte-2b", "us-east-2c"]
    subnets_cidr_block = ["192.168.0.0/24", "192.68.1.0/24", "192.168.2.0/24"]
    private_subnet_id  = ["192.168.3.0/24", "192.168.4.0/24", "192.168.5.0/24"]
    vpc_cidr_block     = "192.168.0.0/16"
    subnet_tags        = ["db", "web", "app", "db1", "web1", "app1"]
    vpc_tags           = "khaja"
  }
}

variable "aws_internet_gateway" {
  type    = string
  default = "true"
}

variable "public_route_table" {
  type = object({
    route_cidr = string
    route_tags = string
    subnet_id  = list(string)
  })
}

variable "private_route_table" {
  type    = list(string)
  default = ["true"]
}

variable "security_group" {
  type = object({
    from_port  = string
    to_port    = string
    protocol   = string
    cidr_block = string

  })
}

variable "aws_instance" {
  type = object({
    ami                         = string
    instance_type               = string
    associate_public_ip_address = string
    key_name                    = string
    tags                        = string
  })
}