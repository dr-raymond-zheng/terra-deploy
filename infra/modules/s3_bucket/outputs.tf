output "id" {
  value = aws_s3_bucket.this.id
}

output "arn" {
  value = aws_s3_bucket.this.arn
}

output "bucket" {
  value = aws_s3_bucket.this.bucket
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.this.bucket_regional_domain_name
}

output "versioning_enabled" {
  value = aws_s3_bucket_versioning.this.versioning_configuration[0].status
}

