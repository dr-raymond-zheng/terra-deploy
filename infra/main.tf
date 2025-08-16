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
  region = var.region
}


locals {
  bucket_name_site = "${var.project}-site-${var.bucket_suffix}"
  bucket_name_logs = "${var.project}-logs-${var.bucket_suffix}"
  tags             = merge({ Project = var.project }, var.tags)
}

# --- GitHub OIDC provider (created once) ---
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # GitHub OIDC root CA thumbprint (verify occasionally)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# --- S3 bucket (private, versioned, encrypted) ---
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

# --- Bucket for Logs ---
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
    }                        # cheap, rapid retrieval
    expiration { days = 90 } # delete after 90 days
  }
}

resource "aws_s3_bucket_logging" "site" {
  bucket        = aws_s3_bucket.site.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3/${aws_s3_bucket.site.id}/"
}

# --- CloudFront OAC ---
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project}-oac"
  description                       = "OAC for private S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- CloudFront distribution ---
resource "aws_cloudfront_distribution" "cdn" {
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs.bucket_regional_domain_name
    prefix          = "cloudfront/"
  }
  enabled             = true
  comment             = var.cloudfront_name
  default_root_object = "index.html"
  price_class         = var.cf_price_class

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      headers      = []
      cookies { forward = "none" }
    }
  }

  # SPA-friendly 404 -> index.html
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["AU"]
    }
  }



  viewer_certificate {
    cloudfront_default_certificate = true
    #    minimum_protocol_version       = "TLSv1.2_2021" # TLSv1 only.
  }

  tags = local.tags
}

# --- Bucket policy to allow only CloudFront (OAC) ---
data "aws_iam_policy_document" "s3_allow_oac" {
  statement {
    sid    = "AllowCloudFrontOACReadOnly"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.s3_allow_oac.json
}

# --- GitHub Actions roles (App & Infra) ---

# App role trust: only pushes to main on the APP repo
data "aws_iam_policy_document" "gha_trust_app" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo_app}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "gha_app" {
  name               = "${var.project}-gha-app"
  assume_role_policy = data.aws_iam_policy_document.gha_trust_app.json
  tags               = local.tags
}

data "aws_iam_policy_document" "app_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:PutObjectAcl", "s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.cdn.arn]
  }
}

resource "aws_iam_policy" "app_policy" {
  name   = "${var.project}-gha-app-policy"
  policy = data.aws_iam_policy_document.app_permissions.json
}

resource "aws_iam_role_policy_attachment" "app_attach" {
  role       = aws_iam_role.gha_app.name
  policy_arn = aws_iam_policy.app_policy.arn
}

data "aws_iam_role" "gha_infra" {
  name = "terra-demo-gha-infra"
}

# SNS topic in ap-southeast-2 for S3 notifications
resource "aws_sns_topic" "s3_site_events" {
  name = "s3-site-events"
}

resource "aws_sns_topic_subscription" "s3_site_events_email" {
  topic_arn = aws_sns_topic.s3_site_events.arn
  protocol  = "email"
  endpoint  = "xiaoming.zheng@icloud.com"
}

# Notify on writes/deletes to index.html (defacement signal)
resource "aws_s3_bucket_notification" "site_events" {
  bucket = aws_s3_bucket.site.id

  topic {
    topic_arn = aws_sns_topic.s3_site_events.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]

    filter_suffix = ".html"
    filter_prefix = "index.html" # effectively matches only index.html
  }
}

resource "aws_sns_topic_policy" "s3_site_events_policy" {
  arn    = aws_sns_topic.s3_site_events.arn
  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action = "SNS:Publish"
        Resource = aws_sns_topic.s3_site_events.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.site.arn
          }
        }
      }
    ]
  })
}
