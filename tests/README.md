# Tests

Tests use the built-in OpenTofu test framework (`tofu test`, OpenTofu 1.9 or later).

| Level | Folder | What it does | Cost | When it runs |
|---|---|---|---|---|
| Unit | `tests/unit` | Plan only with mocked providers. Checks configuration and security settings. | None | Merge requests into `development` or `main`, and tags |
| Integration | `tests/integration` | Deploys real resources, checks them, destroys them. | Cloud cost while running | Tags, when cloud credentials are set (`integration-tests` job) |

In the GitLab pipeline, the `unit-tests` job also publishes the results as a JUnit test report (**Tests** tab of the pipeline and of the merge request). The script `ci/tofu-json-to-junit.py` converts the output of `tofu test -json` to JUnit XML.

## Run locally

```bash
tofu init
tofu test -test-directory=tests/unit
tofu test -test-directory=tests/integration   # needs cloud credentials
```

## Test cases

| ID | Level | Description | Status |
|---|---|---|---|
| U-01 | Unit | Default variables produce a valid plan with all default tags | done |
| U-02 | Unit | Invalid `name_prefix` is rejected | done |
| U-03 | Unit | Custom `advanced_settings.tags` are merged with the default tags | done |
| U-04 | Unit | All four public access block settings are on for both buckets | done |
| U-05 | Unit | ACLs are disabled (`BucketOwnerEnforced`) on both buckets | done |
| U-06 | Unit | Both buckets use SSE-S3 by default | done |
| U-07 | Unit | A KMS key ARN switches the data bucket to SSE-KMS, the log bucket stays on SSE-S3 | done |
| U-08 | Unit | An invalid `kms_key_arn` is rejected | done |
| U-09 | Unit | Bucket policies of both buckets deny requests without TLS and below TLS 1.2 | done |
| U-10 | Unit | Versioning is on by default | done |
| U-11 | Unit | `versioning_enabled = false` suspends versioning and removes the noncurrent version rule | done |
| U-12 | Unit | Old versions expire after 30 days by default | done |
| U-13 | Unit | `noncurrent_version_expiration_days = 0` is rejected | done |
| U-14 | Unit | The data bucket writes server access logs to the log bucket | done |
| U-15 | Unit | The log bucket expires logs after 90 days by default and is versioned | done |
| U-16 | Unit | `log_retention_days` above 3650 is rejected | done |
| U-17 | Unit | `force_destroy` is on by default for both buckets | done |
| U-18 | Unit | `force_destroy = false` applies to both buckets | done |
| I-01 | Integration | Data bucket is created with the expected name and ARN | done |
| I-02 | Integration | Deployed data bucket is private, versioned and logs to the log bucket | done |

Integration tests are written but have not run against a real cloud account yet.
