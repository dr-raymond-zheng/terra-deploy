terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  tags          = var.tags
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = var.block_ignore_acls
  block_public_policy     = true
  ignore_public_acls      = var.block_ignore_acls
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.is_log ? 1 : 0
  bucket = aws_s3_bucket.this.id
  rule {
    id     = "log-retention"
    status = "Enabled"
    filter {
      prefix = ""
    }
    transition {
      days          = 30
      storage_class = "GLACIER_IR"
    }
    expiration { days = 90 }
  }
}

resource "aws_s3_bucket_logging" "this" {
  count         = var.enable_logging ? 1 : 0
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_target_bucket
  target_prefix = "s3/${aws_s3_bucket.this.id}/"
}

resource "aws_s3_bucket_policy" "this" {
  count  = var.attach_policy ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy
}

# Enable CRR on primary -> replica
resource "aws_s3_bucket_replication_configuration" "site" {
  count  = var.enable_replication ? 1 : 0
  bucket = aws_s3_bucket.this.id
  role   = var.replication_role_arn

  rule {
    id     = "everything"
    status = "Enabled"
    destination {
      bucket        = var.replication_dest.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket.this, var.replication_dest]
}