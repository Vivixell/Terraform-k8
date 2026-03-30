terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.9"
    }
  }
}



provider "aws" {
  region = "us-east-1"
}



resource "aws_s3_bucket" "terraform_state" {
  bucket = "ovr-statefile-bucket-unique-name"

  object_lock_enabled = true #Has to be enable from start, else won't work later

  force_destroy = true #Allows to delete bucket even if it has objects in it, but we have to delete all versions and delete markers first
  #Never to be used in production, only for testing purposes

  tags = {
    Name = "terraform-state"
  }
}


resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



/*

aws s3api delete-objects \
  --bucket ovr-statefile-bucket-unique-name \
  --delete "$(aws s3api list-object-versions \
  --bucket ovr-statefile-bucket-unique-name \
  --output=json \
  --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"


aws s3api delete-objects \
  --bucket ovr-statefile-bucket-unique-name \
  --delete "$(aws s3api list-object-versions \
  --bucket ovr-statefile-bucket-unique-name \
  --output=json \
  --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')"

*/
