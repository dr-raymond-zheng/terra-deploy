# --- Website bucket primary ---
module "bucket_site" {
  source                = "./modules/s3_bucket"
  bucket_name           = local.bucket_name_site
  tags                  = local.tags
  enable_logging        = true
  logging_target_bucket = module.bucket_logs.id
  attach_policy         = true
  bucket_policy         = data.aws_iam_policy_document.s3_allow_oac.json
  enable_replication    = true
  replication_role_arn  = aws_iam_role.rep_role.arn
  replication_dest      = module.bucket_site_replica
}

# --- Website bucket replica ---
module "bucket_site_replica" {
  providers             = { aws = aws.mel }
  source                = "./modules/s3_bucket"
  bucket_name           = "${local.bucket_name_site}-replica"
  tags                  = local.tags
  enable_logging        = true
  logging_target_bucket = module.bucket_logs_replica.id
  attach_policy         = true
  bucket_policy         = data.aws_iam_policy_document.s3_rep_allow_oac.json
}

# --- Logs bucket primary ---
module "bucket_logs" {
  source               = "./modules/s3_bucket"
  bucket_name          = local.bucket_name_logs
  tags                 = local.tags
  block_ignore_acls    = false
  is_log               = true
  enable_replication   = true
  replication_role_arn = aws_iam_role.rep_role.arn
  replication_dest     = module.bucket_logs_replica
}

# --- Logs bucket Replica ---
module "bucket_logs_replica" {
  providers   = { aws = aws.mel }
  source      = "./modules/s3_bucket"
  bucket_name = "${local.bucket_name_logs}-replica"
  tags        = local.tags
  is_log      = true
}
