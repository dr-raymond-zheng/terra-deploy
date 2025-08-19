terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region_syd
}

provider "aws" {
  alias  = "mel"
  region = var.region_mel
}

provider "aws" {
  alias  = "us"
  region = var.region_us
}

locals {
  bucket_name_site = "${var.project}-site-${var.bucket_suffix}"
  bucket_name_logs = "${var.project}-logs-${var.bucket_suffix}"
  tags             = merge({ Project = var.project }, var.tags)
}


