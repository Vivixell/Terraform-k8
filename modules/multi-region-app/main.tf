terraform {
    required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.9"
      configuration_aliases = [aws.primary, aws.replica] # Demanding explicit providers
    }
  }
  
}

resource "aws_s3_bucket" "primary" {
  provider      = aws.primary
  bucket_prefix = "${var.app_name}-primary-"
  force_destroy = true
}

resource "aws_s3_bucket" "replica" {
  provider      = aws.replica
  bucket_prefix = "${var.app_name}-replica-"
  force_destroy = true
}

variable "app_name" {
  type = string
}