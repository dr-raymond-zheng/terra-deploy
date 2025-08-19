# SNS resources
resource "aws_sns_topic" "s3_site_events" {
  name = "s3-site-events"
}

resource "aws_sns_topic_subscription" "s3_site_events_email" {
  topic_arn = aws_sns_topic.s3_site_events.arn
  protocol  = "email"
  endpoint  = "xiaoming.zheng@icloud.com"
}

resource "aws_sns_topic_policy" "s3_site_events_policy" {
  arn = aws_sns_topic.s3_site_events.arn
  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.s3_site_events.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = module.bucket_site.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "site_events" {
  bucket = module.bucket_site.id

  topic {
    topic_arn     = aws_sns_topic.s3_site_events.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix = ".html"
    filter_prefix = "index.html"
  }
}
