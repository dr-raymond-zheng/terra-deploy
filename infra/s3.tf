# S3 resources
resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name_site
  tags   = local.tags
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Replica bucket ---
resource "aws_s3_bucket" "site_replica" {
  provider = aws.mel
  bucket   = "${local.bucket_name_site}-replica"
  tags     = local.tags
}
resource "aws_s3_bucket_ownership_controls" "site_replica" {
  provider = aws.mel
  bucket   = aws_s3_bucket.site_replica.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_public_access_block" "site_replica" {
  provider                = aws.mel
  bucket                  = aws_s3_bucket.site_replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "site_replica" {
  provider = aws.mel
  bucket   = aws_s3_bucket.site_replica.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "site_replica" {
  provider = aws.mel
  bucket   = aws_s3_bucket.site_replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Logs bucket ---
resource "aws_s3_bucket" "logs" {
  bucket = local.bucket_name_logs
  tags   = local.tags
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
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

resource "aws_s3_bucket_logging" "site" {
  bucket        = aws_s3_bucket.site.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/${aws_s3_bucket.site.id}/"
}

resource "aws_s3_bucket_logging" "site_replica" {
  provider      = aws.mel
  bucket        = aws_s3_bucket.site_replica.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/${aws_s3_bucket.site_replica.id}/"
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.s3_allow_oac.json
}

resource "aws_s3_bucket_policy" "site_replica" {
  provider = aws.mel
  bucket   = aws_s3_bucket.site_replica.id
  policy   = data.aws_iam_policy_document.s3_rep_allow_oac.json
}

# Enable CRR on primary -> replica
resource "aws_s3_bucket_replication_configuration" "crr" {
  bucket = aws_s3_bucket.site.id
  role   = aws_iam_role.rep_role.arn

  rule {
    id     = "everything"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.site_replica.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.site, aws_s3_bucket_versioning.site_replica]
}

