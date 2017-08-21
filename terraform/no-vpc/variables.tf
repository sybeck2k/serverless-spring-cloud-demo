provider "aws" {
  region     = "us-west-1"
}

variable "lambda-jar" {
  default = "../../target/serverless-spring-cloud-function-1.0-SNAPSHOT-aws.jar"
}

variable "lambda-publisher-name" {
  default = "test-log-publisher"
}

variable "lambda-consumer-name" {
  default = "test-log-consumer"
}
