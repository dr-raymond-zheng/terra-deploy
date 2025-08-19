variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket."
}

variable "bucket_policy" {
  type        = any
  default     = null
  description = "S3 bucket policy in JSON."
}

variable "block_ignore_acls" {
  type        = bool
  default     = true
  description = "Boolen for block_public_acls and ignore_public_acls."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the bucket."
}

variable "is_log" {
  type        = bool
  default     = false
  description = "Configure log retention?"
}

variable "enable_logging" {
  type    = bool
  default = false
}

variable "enable_replication" {
  type    = bool
  default = false
}
variable "attach_policy" {
  type    = bool
  default = false
}
variable "logging_target_bucket" {
  type        = string
  default     = ""
  description = "Target bucket for access logs."
}

variable "replication_role_arn" {
  type        = string
  default     = ""
  description = "ARN of the replication IAM role"
}

variable "replication_dest" {
  type        = any
  default     = null
  description = "Module output object for the replication destination bucket"
}