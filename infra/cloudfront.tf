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
    bucket          = module.bucket_logs.bucket_regional_domain_name
    prefix          = "cloudfront/"
  }
  web_acl_id          = aws_wafv2_web_acl.waf.arn
  enabled             = true
  comment             = var.cloudfront_name
  default_root_object = "index.html"
  price_class         = var.cf_price_class

  origin {
    domain_name              = module.bucket_site.bucket_regional_domain_name
    origin_id                = "s3-${module.bucket_site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  origin {
    domain_name              = module.bucket_site_replica.bucket_regional_domain_name
    origin_id                = "s3-${module.bucket_site_replica.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  origin_group {
    origin_id = "group-s3"
    failover_criteria { status_codes = [500, 502, 503, 504] }
    member { origin_id = "s3-${module.bucket_site.id}" }         # primary
    member { origin_id = "s3-${module.bucket_site_replica.id}" } # secondary
  }

  default_cache_behavior {
    response_headers_policy_id = aws_cloudfront_response_headers_policy.csp.id
    cache_policy_id            = aws_cloudfront_cache_policy.cache.id
    target_origin_id           = "s3-${module.bucket_site.id}"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
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
    response_page_path    = "/limit.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["AU", "US"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    #    minimum_protocol_version       = "TLSv1.2_2021" # TLSv1 only.
  }

  tags = local.tags
}

resource "aws_cloudfront_response_headers_policy" "csp" {
  name = "app-csp-policy"

  security_headers_config {
    content_type_options {
      override = true
    }
    content_security_policy {
      override                = true
      content_security_policy = "default-src 'self'; base-uri 'self'; frame-ancestors 'none'; img-src 'self' data:; font-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self' https://api.example.com; form-action 'self'; upgrade-insecure-requests"
    }

    referrer_policy {
      override        = true
      referrer_policy = "strict-origin-when-cross-origin"
    }

    strict_transport_security {
      override                   = true
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = false
    }

    xss_protection {
      override   = true
      protection = true
      mode_block = true
    }
    frame_options {
      override     = true
      frame_option = "SAMEORIGIN"
    }
  }
}

resource "aws_cloudfront_cache_policy" "cache" {
  name        = "app-cache-policy"
  default_ttl = 3600
  max_ttl     = 86400
  min_ttl     = 0
  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}