provider "aws" {
  region     = "us-west-1"
}

variable "lambda-jar" {
  default = "../../target/spring-cloud-function-1.0-SNAPSHOT-aws.jar"
}

variable "dmz_subnet" {
  default = "10.0.254.0/28"
}

variable "subnet1" {
  default = "10.0.1.0/24"
}

variable "subnet2" {
  description = "The AZ for the first public subnet, e.g: us-east-1a"
  default = "10.0.2.0/24"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnetaz1" {
  type = "map"

  default = {
    us-east-1 = "us-east-1a"
    us-east-2 = "us-east-2a"
    us-west-1 = "us-west-1a"
    us-west-2 = "us-west-2a"
    eu-west-1 = "eu-west-1a"
    eu-west-2 = "eu-west-2a"
    eu-central-1 = "eu-central-1a"
    ap-southeast-1 = "ap-southeast-1a"
  }
}

//  This map defines which AZ to put 'Public Subnet B' in, based on the
//  region defined. You will typically not need to change this unless
//  you are running in a new region!
variable "subnetaz2" {
  type = "map"

  default = {
    us-east-1 = "us-east-1b"
    us-east-2 = "us-east-2b"
    us-west-1 = "us-west-1b"
    us-west-2 = "us-west-2b"
    eu-west-1 = "eu-west-1b"
    eu-west-2 = "eu-west-2b"
    eu-central-1 = "eu-central-1b"
    ap-southeast-1 = "ap-southeast-1b"
  }
}

variable "lambda-publisher-name" {
  default = "test-log-publisher"
}

variable "lambda-consumer-name" {
  default = "test-log-consumer"
}