# Integration tests: deploy real resources, check them, then destroy them.
# This costs money and needs cloud credentials.
# Run: tofu test -test-directory=tests/integration
# Test case catalog: tests/README.md

variables {
  name_prefix = "itest"
  advanced_settings = {
    tags = {
      Purpose = "integration-test"
    }
  }
}

# I-01
run "deploy" {
  command = apply

  assert {
    condition     = startswith(output.bucket_name, "itest-data-") && output.bucket_arn == "arn:aws:s3:::${output.bucket_name}"
    error_message = "The data bucket was not created with the expected name."
  }
}

# I-02
run "buckets_are_private_and_versioned" {
  command = plan

  assert {
    condition = (
      aws_s3_bucket_public_access_block.data.block_public_policy &&
      aws_s3_bucket_versioning.data.versioning_configuration[0].status == "Enabled" &&
      aws_s3_bucket_logging.data.target_bucket == aws_s3_bucket.logs.id
    )
    error_message = "The deployed bucket is not private, versioned and logged."
  }
}
