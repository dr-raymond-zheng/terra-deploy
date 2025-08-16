# --- GitHub OIDC provider (created once) ---
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # GitHub OIDC root CA thumbprint (verify occasionally)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

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
data "aws_iam_policy_document" "s3_rep_allow_oac" {
  statement {
    sid    = "AllowCloudFrontOACReadOnly"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site_replica.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

# GitHub Actions roles (App & Infra)
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

# Replication role
data "aws_iam_policy_document" "rep_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "rep_role" {
  name               = "s3-replication-role"
  assume_role_policy = data.aws_iam_policy_document.rep_trust.json
}
data "aws_iam_policy_document" "rep_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObjectVersion", "s3:GetObjectVersionAcl", "s3:GetObjectVersionForReplication", "s3:GetObjectLegalHold", "s3:GetObjectVersionTagging", "s3:GetObjectRetention"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:ObjectOwnerOverrideToBucketOwner"]
    resources = ["${aws_s3_bucket.site_replica.arn}/*"]
  }
}
resource "aws_iam_policy" "rep_policy" {
  name   = "s3-replication-policy"
  policy = data.aws_iam_policy_document.rep_policy.json
}
resource "aws_iam_role_policy_attachment" "rep_attach" {
  role       = aws_iam_role.rep_role.name
  policy_arn = aws_iam_policy.rep_policy.arn
}
