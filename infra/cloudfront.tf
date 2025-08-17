# CloudFront resources

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project}-oac"
  description                       = "OAC for private S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs.bucket_regional_domain_name
    prefix          = "cloudfront/"
  }
  web_acl_id          = aws_wafv2_web_acl.waf.arn
  enabled             = true
  comment             = var.cloudfront_name
  default_root_object = "index.html"
  price_class         = var.cf_price_class

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  origin {
    domain_name              = aws_s3_bucket.site_replica.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.site_replica.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  origin_group {
    origin_id = "group-s3"
    failover_criteria { status_codes = [500, 502, 503, 504] }
    member { origin_id = "s3-${aws_s3_bucket.site.id}" }         # primary
    member { origin_id = "s3-${aws_s3_bucket.site_replica.id}" } # secondary
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

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }
  custom_error_response {
    error_code            = 403
    response_code         = 403
    response_page_path    = "/rate-limit.html"
    error_caching_min_ttl = 60
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