# AWS Secure Object Storage (S3)

Creates a private S3 bucket for files, backups, exports or application data, plus a second bucket for its access logs. There is no website, CDN or network: access is controlled by AWS identities.

Use it when an application or a demo needs a secure place to store objects. For a website, use the static website template.

## What gets created

- A data bucket with all four public access settings on, ACLs disabled, encryption, versioning and a lifecycle rule for old versions
- Bucket policies that deny requests without TLS and requests below TLS 1.2, on both buckets
- A log bucket that receives the server access logs of the data bucket and deletes them after the retention period

## Before you start

- A workflow with an AWS cloud connector for the target account
- Permissions to create S3 buckets, bucket policies and bucket settings
- Optional: a KMS key in the same region, if you want SSE-KMS instead of the default SSE-S3

## Form fields

| Field | What it does | Default |
|---|---|---|
| Name prefix | Prefix for the bucket names. 2 to 16 lowercase letters, digits or hyphens, starting with a letter. A random suffix is added because bucket names are global | `demo` |
| Region | AWS region | `eu-central-1` |

**Advanced Settings** (tick "Show advanced settings" to change them):

| Field | What it does | Default |
|---|---|---|
| Versioning enabled | Keeps old versions of objects | on |
| Old version expiration days | Deletes old versions after this many days. Needs versioning | `30` |
| KMS key ARN | Encrypts the data bucket with this KMS key (SSE-KMS). Empty means SSE-S3 | empty |
| Access log retention days | How long the server access logs are kept | `90` |
| Force destroy | Deletes all objects when the buckets are destroyed. Turn it off to protect the data | on |
| Tags | Extra tags added to all resources | none |

## After the run

The workflow outputs show:

- `bucket_name` and `bucket_arn`: the data bucket
- `region`: the region of the buckets
- `log_bucket_name`: the bucket with the access logs

The buckets have no access for anyone except identities that your IAM policies allow. Give your users or roles access to the bucket in IAM, for example `s3:GetObject`, `s3:PutObject` and `s3:ListBucket` on `bucket_arn`. With a KMS key, the key policy must also allow them to use the key.

## Security defaults

- No public access: block public access is on for both buckets, ACLs are disabled
- Encrypted at rest with SSE-S3, or with your KMS key
- TLS 1.2 or newer is required
- Versioning is on, old versions expire after 30 days
- Server access logs go to the log bucket. S3 delivers them on a best-effort basis, so they can arrive with a delay

## Cost and cleanup

You pay for the stored data, requests and the logs. An empty demo costs close to nothing. A KMS key adds a monthly fee and a charge per request. Destroy the resources from the workflow when the demo is over. With Force destroy on (the default), all objects, including old versions, are deleted with the buckets. Turn it off for data that you want to keep: the destroy then fails while the buckets still contain objects.

## Limits

- Single region, no cross-region replication
- No VPC endpoint: requests go through the S3 public endpoints, protected by TLS and IAM
- No event notifications or object lock
- The log bucket always uses SSE-S3, because S3 log delivery does not support KMS
