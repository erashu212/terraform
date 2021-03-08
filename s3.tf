data "aws_iam_policy_document" "assume_role_policy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["s3.amazonaws.com"]
      type        = "Service"
    }
    effect = "Allow"
    sid    = ""
  }
}

data "aws_iam_policy_document" "assume_role_policy_for_failover" {
  version = "2012-10-17"
  statement {
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    effect    = "Allow"
    resources = [aws_s3_bucket.primary.arn]
  }
  statement {
    actions   = ["s3:GetObjectVersion", "s3:GetObjectVersionAcl"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.primary.arn}/*"]
  }
  dynamic "statement" {
    for_each = local.high_availability ? [local.high_availability] : []
    content {
      actions   = ["s3:ReplicateObject", "s3:ReplicateDelete"]
      effect    = "Allow"
      resources = ["${aws_s3_bucket.failover[0].arn}/*"]
    }
  }
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    effect = "Allow"
    resources = [
      aws_s3_bucket.primary.arn,
      "${aws_s3_bucket.primary.arn}/*"
    ]
    actions = ["s3:PutObject", "s3:PutObjectAcl"]
    principals {
      identifiers = [local.aws_iam_user]
      type        = "AWS"
    }
  }
  statement {
    effect    = "Allow"
    resources = [aws_s3_bucket.primary.arn]
    actions   = ["s3:ListBucket"]
    principals {
      identifiers = [
        aws_cloudfront_origin_access_identity.primary.iam_arn,
        local.aws_iam_user
      ]
      type = "AWS"
    }
  }
  statement {
    effect = "Allow"
    resources = [
      aws_s3_bucket.primary.arn,
      "${aws_s3_bucket.primary.arn}/*"
    ]
    actions = ["s3:GetObject"]
    principals {
      identifiers = [aws_cloudfront_origin_access_identity.primary.iam_arn]
      type        = "AWS"
    }
  }
}

data "aws_iam_policy_document" "s3_failover_bucket_policy" {
  dynamic "statement" {
    for_each = local.high_availability ? [local.high_availability] : []
    content {
      effect = "Allow"
      resources = [
        aws_s3_bucket.failover[0].arn,
        "${aws_s3_bucket.failover[0].arn}/*"
      ]
      actions = ["s3:PutObject", "s3:PutObjectAcl"]
      principals {
        identifiers = [local.aws_iam_user]
        type        = "AWS"
      }
    }
  }
  dynamic "statement" {
    for_each = local.high_availability ? [local.high_availability] : []
    content {
      effect    = "Allow"
      resources = [aws_s3_bucket.failover[0].arn]
      actions   = ["s3:ListBucket"]
      principals {
        identifiers = [
          aws_cloudfront_origin_access_identity.failover[0].iam_arn,
          local.aws_iam_user
        ]
        type = "AWS"
      }
    }
  }
  dynamic "statement" {
    for_each = local.high_availability ? [local.high_availability] : []
    content {
      effect = "Allow"
      resources = [
        aws_s3_bucket.failover[0].arn,
        "${aws_s3_bucket.failover[0].arn}/*"
      ]
      actions = ["s3:GetObject"]
      principals {
        identifiers = [aws_cloudfront_origin_access_identity.failover[0].iam_arn]
        type        = "AWS"
      }
    }
  }
}

resource "random_pet" "role" {
  keepers = {
    # Generate a new pet name each time we switch to a new AMI id
    role_name = local.s3_bucket_name
  }
}

resource "aws_iam_role" "replication" {
  count              = local.high_availability ? 1 : 0
  name               = random_pet.role.id
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_policy" "replication" {
  count  = local.high_availability ? 1 : 0
  name   = random_pet.role.id
  policy = data.aws_iam_policy_document.assume_role_policy_for_failover.json
}

resource "aws_iam_role_policy_attachment" "site_replication" {
  count      = local.high_availability ? 1 : 0
  policy_arn = aws_iam_policy.replication[0].arn
  role       = aws_iam_role.replication[0].name
}

resource "aws_s3_bucket" "failover" {
  count         = local.high_availability ? 1 : 0
  bucket        = local.s3_failover_bucket_name
  provider      = aws.failover_region
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  tags = {
    name        = "${local.s3_failover_bucket_name}-bucket-failover"
    environment = var.environment
  }

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.allowed_domains
    max_age_seconds = "3000"
  }

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "aws_s3_bucket" "primary" {
  bucket        = local.s3_bucket_name
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  tags = {
    name        = "${local.s3_bucket_name}-bucket-primary"
    environment = var.environment
  }

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.allowed_domains
    max_age_seconds = "3000"
  }

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  dynamic "replication_configuration" {
    for_each = local.high_availability ? [local.high_availability] : []
    content {
      role = aws_iam_role.replication[0].arn
      rules {
        id     = "failover_s3_bucket_replication"
        status = "Enabled"
        filter {
          prefix = ""
        }
        destination {
          bucket        = aws_s3_bucket.failover[0].arn
          storage_class = "STANDARD"
        }
      }
    }
  }
}

resource "aws_s3_bucket_policy" "primary" {
  bucket = aws_s3_bucket.primary.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

resource "aws_s3_bucket_policy" "failover" {
  count    = local.high_availability ? 1 : 0
  bucket   = aws_s3_bucket.failover[0].id
  provider = aws.failover_region
  policy   = data.aws_iam_policy_document.s3_failover_bucket_policy.json
}
