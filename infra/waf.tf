resource "aws_wafv2_web_acl" "waf" {
  provider    = aws.us
  name        = "waf"
  description = "WAF for CloudFront"
  scope       = "CLOUDFRONT"
  default_action {
    allow {}
  }
  rule {
    name     = "rate-limit"
    priority = 2
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit                 = 10
        evaluation_window_sec = 60
        aggregate_key_type    = "IP"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "cf-waf-common"
    }
  }
  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "waf"
  }
  tags = local.tags
}
