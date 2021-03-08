data "aws_acm_certificate" "this" {
  count    = var.cert_domain != "" ? 1 : 0
  domain   = local.cert_domain
  provider = aws.useast1
  statuses = [
  "ISSUED"]
  most_recent = true
}

resource "aws_acm_certificate" "this" {
  count             = var.cert_domain != "" ? 0 : 1
  domain_name       = local.cert_domain
  validation_method = "DNS"
  provider          = aws.useast1

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  count = var.cert_domain != "" ? 0 : 1
  name  = lookup(local.dvo[count.index], "resource_record_name")
  records = [
  lookup(local.dvo[count.index], "resource_record_value")]
  ttl     = 60
  type    = lookup(local.dvo[count.index], "resource_record_type")
  zone_id = data.aws_route53_zone.this.zone_id
  depends_on = [
  aws_acm_certificate.this]
}

resource "aws_acm_certificate_validation" "this" {
  count           = var.cert_domain != "" ? 0 : 1
  certificate_arn = element(aws_acm_certificate.this.*.arn, count.index)

  validation_record_fqdns = [
    element(aws_route53_record.cert_validation.*.fqdn, count.index)
  ]
  provider = aws.useast1

  timeouts {
    create = "60m"
  }
}
