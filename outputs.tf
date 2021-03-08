output "cloudfront_arn" {
  description = "Cloudfront Arn of the static site"
  value       = aws_cloudfront_distribution.this.arn
}

output "cloudfront_id" {
  description = "Cloudfront id of the static site"
  value       = aws_cloudfront_distribution.this.id
}

output "s3_bucket_name" {
  description = "Primary S3 bucket name of the static site"
  value       = aws_s3_bucket.primary.id
}

output "domain" {
  description = "Route53 domain name"
  value       = aws_route53_record.this.name
}
