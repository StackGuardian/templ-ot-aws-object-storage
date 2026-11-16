output "bucket_name" {
  description = "Name of the data bucket"
  value       = aws_s3_bucket.data.id
}

output "bucket_arn" {
  description = "ARN of the data bucket"
  value       = aws_s3_bucket.data.arn
}

output "region" {
  description = "Region of the buckets"
  value       = var.region
}

output "log_bucket_name" {
  description = "Name of the bucket that receives the server access logs"
  value       = aws_s3_bucket.logs.id
}
