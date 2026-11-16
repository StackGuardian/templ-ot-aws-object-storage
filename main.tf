locals {
  tags = merge(
    {
      Project     = var.name_prefix
      Environment = "demo"
      ManagedBy   = "opentofu"
      Repository  = "tf-aws-object-storage"
    },
    var.advanced_settings.tags,
  )

  use_kms = var.advanced_settings.kms_key_arn != ""
}

data "aws_caller_identity" "current" {}
