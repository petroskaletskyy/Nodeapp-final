variable "project" {
  description   = "Name of the project deployment"
  type          = string
  default       = "nodeapp-final"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.1.0.0/16"
}

variable "subnet_cidr_bits" {
  description = "The number of subnet bits for the CIDR. For example, specifying a value 8 for this parameter will create a CIDR with a mask of /24."
  type        = number
  default     = 8
}

variable "region" {
  description = "The aws region. https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html"
  type        = string
  default     = "eu-west-1"
}

variable "availability_zones_count" {
  description = "The number of AZs."
  type        = number
  default     = 2
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    "Project"     = "Nodeapp-final"
    "Environment" = "Development"
    "Owner"       = "Petro Skaletskyy"
  }
}

variable "db_settings" {
  description   = "Configuration settings"
  type          = map(any)
  default = {
    "database" = {
        allocated_storage   = 10
        engine              = "mysql"
        engine_version      = "8.0.28"
        instance_class      = "db.t2.micro"
        db_name             = "reserve_db"
        skip_final_snapshot = true
    }
  }
}

variable "db_username" {
  description   = "Database master user"
  type          = string
  sensitive     = true
}

variable "db_password" {
  description   = "Database master user password"
  type          = string
  sensitive     = true
}