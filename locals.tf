locals {
  regionNames = [
    "us-east-1",
    "us-west-2",
    "us-east-2",
  "us-west-1"]
  failover_region = [
    for rn in local.regionNames :
    rn if rn != var.region
  ][0]

  s3_bucket_name          = format("tonara-%s%s%s", var.module_name != "" ? "${var.module_name}-" : "", var.environment != "" ? "${var.environment}-" : "", data.aws_region.active.name)
  s3_failover_bucket_name = format("tonara-%s%s%s", var.module_name != "" ? "${var.module_name}-" : "", var.environment != "" ? "${var.environment}-" : "", local.failover_region)
  allowed_domains         = length(var.allowed_domains) != 0 ? var.allowed_domains : []
  aws_iam_user            = data.aws_caller_identity.active.arn
  cert_domain             = var.cert_domain == "" ? format("%s%s%s", var.environment != "" ? "${var.environment}." : "", var.module_name != "" ? "${var.module_name}." : "", var.hosted_zone) : var.cert_domain
  fqdn                    = format("%s%s%s", var.environment != "" ? "${var.environment}." : "", var.module_name != "" ? "${var.module_name}." : "", var.hosted_zone)
  high_availability       = var.high_availability
  bucket_list = local.high_availability ? [
    local.s3_bucket_name,
    local.s3_failover_bucket_name] : [
  local.s3_bucket_name]
  dvo = flatten(aws_acm_certificate.this.*.domain_validation_options)
}
