output "bucket_name" {
  value = module.bucket_site.bucket
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}

output "gha_app_role_arn" {
  value = aws_iam_role.gha_app.arn
}

output "gha_infra_role_arn" {
  value = data.aws_iam_role.gha_infra.arn
}