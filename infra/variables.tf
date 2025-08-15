variable "cloudfront_name" {
  description = "Name for the CloudFront distribution"
  type        = string
}
variable "bucket_suffix" {
  description = "Fixed random string for bucket naming"
  type        = string
}
variable "project" {
  description = "Project slug"
  type        = string
  default     = "terra-demo"
}
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

# Repos used in GitHub OIDC trust conditions
variable "github_repo_app" {
  description = "OWNER/REPO for the App pipeline (S3 sync)"
  type        = string
  default     = "dr-raymond-zheng/static-app"
}

variable "github_repo_infra" {
  description = "OWNER/REPO for the Infra pipeline (Terraform)"
  type        = string
  default     = "dr-raymond-zheng/terra-deploy"
}

variable "cf_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = { Owner = "dr-raymond-zheng", Environment = "prod" }
}
