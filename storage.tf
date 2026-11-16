# Data bucket: private, encrypted, versioned, TLS only, access logged.
resource "aws_s3_bucket" "data" {
  #checkov:skip=CKV_AWS_21:Versioning is on by default and configurable (advanced_settings.versioning_enabled)
  #checkov:skip=CKV_AWS_144:Cross-region replication is out of scope for the demo
  #checkov:skip=CKV_AWS_145:SSE-S3 is the default, a customer-managed KMS key is optional (advanced_settings.kms_key_arn)
  #checkov:skip=CKV2_AWS_62:Event notifications are not needed
  bucket_prefix = "${var.name_prefix}-data-"
  force_destroy = var.advanced_settings.force_destroy
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    bucket_key_enabled = local.use_kms

    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms ? var.advanced_settings.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = var.advanced_settings.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    filter {}

    dynamic "noncurrent_version_expiration" {
      for_each = var.advanced_settings.versioning_enabled ? [1] : []

      content {
        noncurrent_days = var.advanced_settings.noncurrent_version_expiration_days
      }
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.data]
}

# Deny every request that does not use TLS 1.2 or newer.
resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyOldTlsVersions"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
        Condition = {
          NumericLessThan = { "s3:TlsVersion" = "1.2" }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.data]
}

resource "aws_s3_bucket_logging" "data" {
  bucket        = aws_s3_bucket.data.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "data/"
}

# Log bucket: receives the server access logs of the data bucket.
#trivy:ignore:AVD-AWS-0089 This bucket is the log target. Logging it would need a third bucket
resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_18:This bucket is the log target. Logging it would need a third bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication is out of scope for the demo
  #checkov:skip=CKV_AWS_145:Server access log delivery supports only SSE-S3
  #checkov:skip=CKV2_AWS_62:Event notifications are not needed
  bucket_prefix = "${var.name_prefix}-logs-"
  force_destroy = var.advanced_settings.force_destroy
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

#trivy:ignore:AVD-AWS-0132 Server access log delivery supports only SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.advanced_settings.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

# Only S3 log delivery for the data bucket may write, and only over TLS.
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3LogDelivery"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/data/*"
        Condition = {
          ArnLike      = { "aws:SourceArn" = aws_s3_bucket.data.arn }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}
