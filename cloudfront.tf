resource "aws_cloudfront_origin_access_identity" "primary" {
  comment = "Origin access identity for ${local.fqdn} environment"
}

resource "aws_cloudfront_origin_access_identity" "failover" {
  count    = local.high_availability ? 1 : 0
  provider = aws.failover_region
  comment  = "Origin access identity for ${local.fqdn} environment in failover region"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloudfront for ${var.environment} environment."
  default_root_object = "index.html"
  aliases = [
  local.fqdn]

  tags = {
    Environment = var.environment
  }

  dynamic "origin_group" {
    for_each = local.high_availability ? [
    local.high_availability] : []
    content {
      origin_id = "cloudfront_group"
      failover_criteria {
        status_codes = [
          403,
          404,
          500,
        502]
      }
      member {
        origin_id = local.s3_bucket_name
      }
      member {
        origin_id = local.s3_failover_bucket_name
      }
    }
  }

  dynamic "origin" {
    for_each = [
      for idx, bn in local.bucket_list : {
        name       = bn
        domainName = idx == 1 ? aws_s3_bucket.failover[0].bucket_regional_domain_name : aws_s3_bucket.primary.bucket_regional_domain_name
        user       = idx == 1 ? aws_cloudfront_origin_access_identity.failover[0].cloudfront_access_identity_path : aws_cloudfront_origin_access_identity.primary.cloudfront_access_identity_path
    }]
    content {
      domain_name = origin.value.domainName
      origin_id   = origin.value.name
      s3_origin_config {
        origin_access_identity = origin.value.user
      }
    }
  }

  default_cache_behavior {
    target_origin_id = local.high_availability ? "cloudfront_group" : local.s3_bucket_name
    allowed_methods = [
      "GET",
    "HEAD"]
    cached_methods = [
      "GET",
    "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = false
    // default compression  is disabled to serve by lambda

    forwarded_values {
      query_string = false
      headers = [
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method",
        "Origin",
        "Accept-Encoding"
      ]
      cookies {
        forward = "none"
      }
    }

    dynamic "lambda_function_association" {
      for_each = length(var.lambdas) != 0 ? var.lambdas : []
      content {
        event_type   = lookup(lambda_function_association.value, "type")
        lambda_arn   = lookup(lambda_function_association.value, "arn")
        include_body = lookup(lambda_function_association.value, "includeBody")
      }
    }
  }

  custom_error_response {
    error_caching_min_ttl = 3000
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 3000
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  price_class  = "PriceClass_All"
  http_version = "http1.1"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    minimum_protocol_version = "TLSv1.2_2019"
    acm_certificate_arn      = var.cert_domain != "" ? data.aws_acm_certificate.this[0].arn : aws_acm_certificate.this[0].arn
    ssl_support_method       = "sni-only"
  }

  depends_on = [
    aws_acm_certificate.this,
    aws_acm_certificate_validation.this
  ]
}
