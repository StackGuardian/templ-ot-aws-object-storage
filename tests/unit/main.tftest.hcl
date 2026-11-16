# Unit tests: plan only, providers are mocked. No cloud account, no cost.
# Run: tofu test -test-directory=tests/unit
# Test case catalog: tests/README.md

# Some arguments are validated as ARNs, so mocked values must look like ARNs.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::mock-bucket"
    }
  }
}

# U-01
run "defaults_are_valid" {
  command = plan

  assert {
    condition = (
      local.tags["Environment"] == "demo" &&
      local.tags["ManagedBy"] == "opentofu" &&
      local.tags["Project"] == var.name_prefix &&
      local.tags["Repository"] != ""
    )
    error_message = "Default tags are missing or wrong."
  }
}

# U-02
run "invalid_name_prefix_is_rejected" {
  command = plan

  variables {
    name_prefix = "Invalid_Prefix"
  }

  expect_failures = [var.name_prefix]
}

# U-03
run "custom_tags_are_merged" {
  command = plan

  variables {
    advanced_settings = {
      tags = { Owner = "tester" }
    }
  }

  assert {
    condition     = local.tags["Owner"] == "tester" && local.tags["ManagedBy"] == "opentofu"
    error_message = "Custom tags must be merged with the default tags."
  }
}

# U-04
run "public_access_is_blocked_on_both_buckets" {
  command = plan

  assert {
    condition = alltrue([
      for b in [aws_s3_bucket_public_access_block.data, aws_s3_bucket_public_access_block.logs] :
      b.block_public_acls && b.block_public_policy && b.ignore_public_acls && b.restrict_public_buckets
    ])
    error_message = "All four public access block settings must be on for both buckets."
  }
}

# U-05
run "acls_are_disabled" {
  command = plan

  assert {
    condition = (
      aws_s3_bucket_ownership_controls.data.rule[0].object_ownership == "BucketOwnerEnforced" &&
      aws_s3_bucket_ownership_controls.logs.rule[0].object_ownership == "BucketOwnerEnforced"
    )
    error_message = "ACLs must be disabled with BucketOwnerEnforced."
  }
}

# U-06
run "default_encryption_is_sse_s3" {
  command = plan

  assert {
    condition = (
      one(aws_s3_bucket_server_side_encryption_configuration.data.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256" &&
      one(aws_s3_bucket_server_side_encryption_configuration.logs.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    )
    error_message = "Both buckets must use SSE-S3 by default."
  }
}

# U-07
run "kms_key_switches_data_bucket_to_sse_kms" {
  command = plan

  variables {
    advanced_settings = {
      kms_key_arn = "arn:aws:kms:eu-central-1:123456789012:key/11111111-2222-3333-4444-555555555555"
    }
  }

  assert {
    condition = (
      one(aws_s3_bucket_server_side_encryption_configuration.data.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms" &&
      one(aws_s3_bucket_server_side_encryption_configuration.data.rule).apply_server_side_encryption_by_default[0].kms_master_key_id == var.advanced_settings.kms_key_arn &&
      one(aws_s3_bucket_server_side_encryption_configuration.logs.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    )
    error_message = "The data bucket must use the KMS key. The log bucket stays on SSE-S3."
  }
}

# U-08
run "invalid_kms_key_arn_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      kms_key_arn = "not-an-arn"
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-09
run "bucket_policies_deny_insecure_transport" {
  command = plan

  assert {
    condition = alltrue([
      for p in [aws_s3_bucket_policy.data.policy, aws_s3_bucket_policy.logs.policy] :
      anytrue([
        for s in jsondecode(p).Statement :
        s.Effect == "Deny" && s.Action == "s3:*" && try(s.Condition.Bool["aws:SecureTransport"], "") == "false"
      ])
    ])
    error_message = "Both bucket policies must deny requests without TLS."
  }

  assert {
    condition = alltrue([
      for p in [aws_s3_bucket_policy.data.policy, aws_s3_bucket_policy.logs.policy] :
      anytrue([
        for s in jsondecode(p).Statement :
        s.Effect == "Deny" && try(s.Condition.NumericLessThan["s3:TlsVersion"], "") == "1.2"
      ])
    ])
    error_message = "Both bucket policies must deny TLS versions below 1.2."
  }
}

# U-10
run "versioning_is_on_by_default" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.data.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be enabled by default."
  }
}

# U-11
run "versioning_can_be_switched_off" {
  command = plan

  variables {
    advanced_settings = {
      versioning_enabled = false
    }
  }

  assert {
    condition = (
      aws_s3_bucket_versioning.data.versioning_configuration[0].status == "Suspended" &&
      length(one(aws_s3_bucket_lifecycle_configuration.data.rule).noncurrent_version_expiration) == 0
    )
    error_message = "Without versioning there is no versioning status and no noncurrent version rule."
  }
}

# U-12
run "noncurrent_versions_expire_after_30_days_by_default" {
  command = plan

  assert {
    condition     = one(one(aws_s3_bucket_lifecycle_configuration.data.rule).noncurrent_version_expiration).noncurrent_days == 30
    error_message = "Old versions must expire after 30 days by default."
  }
}

# U-13
run "noncurrent_version_expiration_out_of_range_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      noncurrent_version_expiration_days = 0
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-14
run "server_access_logs_go_to_the_log_bucket" {
  command = plan

  assert {
    condition     = aws_s3_bucket_logging.data.target_prefix == "data/"
    error_message = "The data bucket must write server access logs to the log bucket."
  }
}

# U-15
run "log_bucket_expires_logs_after_the_retention_period" {
  command = plan

  assert {
    condition = (
      one(one(aws_s3_bucket_lifecycle_configuration.logs.rule).expiration).days == 90 &&
      aws_s3_bucket_versioning.logs.versioning_configuration[0].status == "Enabled"
    )
    error_message = "Logs must expire after 90 days by default."
  }
}

# U-16
run "log_retention_out_of_range_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      log_retention_days = 3651
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-17
run "force_destroy_is_on_by_default_and_can_be_switched_off" {
  command = plan

  assert {
    condition     = aws_s3_bucket.data.force_destroy && aws_s3_bucket.logs.force_destroy
    error_message = "force_destroy must default to true for demos."
  }
}

# U-18
run "force_destroy_off_protects_both_buckets" {
  command = plan

  variables {
    advanced_settings = {
      force_destroy = false
    }
  }

  assert {
    condition     = !aws_s3_bucket.data.force_destroy && !aws_s3_bucket.logs.force_destroy
    error_message = "force_destroy = false must apply to both buckets."
  }
}
