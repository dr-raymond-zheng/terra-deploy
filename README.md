# terra-deploy (Infrastructure as Code)
This repository provisions the static website stack in AWS ap-southeast-2

## Prerequisites
* AWS Account
* GitHub Account with 2 repos: [static-app](https://github.com/dr-raymond-zheng/static-app.git) and [terra-deploy](https://github.com/dr-raymond-zheng/terra-deploy.git)

## Created Roles
Two IAM roles are created for GitHub Actions via OIDC:
- App role:  Used by *app-code* repo workflow to upload to S3 and invalidate CloudFront.
- Infra role: Used by this repo to run Terraform.

## Created AWS Resources
- 3 Private S3 bucket (versioned, SSE-S3)
- 1 Public S3 bucket (versioned, SSE-S3) for CloudFront logging
- CloudFront distribution with Origin Access Control (OAC)
- WAF with Anti-DDos, rate limit etc.
- IAM OpenID Connect provider for GitHub
- IAM roles for App and Infra (least privilege)
- Terraform outputs for easy wiring to the app repo pipeline

## Quick start
```bash
cd infra
terraform init
terraform apply -auto-approve
```

Record outputs:
- `bucket_name`
- `cloudfront_domain_name`
- `cloudfront_distribution_id`
- `gha_app_role_arn`
- `gha_infra_role_arn`

### Set GitHub Actions Variables
- In app-code repo: sets `GHA_APP_ROLE_ARN`, `S3_BUCKET`, `CF_DIST_ID`.
- In terra-deploy repo (this one): sets `GHA_INFRA_ROLE_ARN`.

### CI/CD
- This repo has `.github/workflows/infra-deploy.yml` that plans/applies Terraform on changes to `infra/`.
- The app-code repo has its own workflow to build & deploy the React app.
