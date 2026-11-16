variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.name_prefix)) && !endswith(var.name_prefix, "-")
    error_message = "Use 2-16 lowercase letters, digits or hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

# Grouped so the StackGuardian form can show them in one "Advanced Settings" section.
variable "advanced_settings" {
  description = "Settings most deployments keep at their defaults"
  type = object({
    versioning_enabled                 = optional(bool, true)      # Keep old versions of objects
    noncurrent_version_expiration_days = optional(number, 30)      # Days after which old versions are deleted (needs versioning)
    kms_key_arn                        = optional(string, "")      # ARN of a KMS key for SSE-KMS. Empty means SSE-S3.
    log_retention_days                 = optional(number, 90)      # Days to keep server access logs
    force_destroy                      = optional(bool, true)      # Delete all objects when the buckets are destroyed. Off protects the data.
    tags                               = optional(map(string), {}) # Additional tags for all resources
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.advanced_settings.noncurrent_version_expiration_days >= 1 && var.advanced_settings.noncurrent_version_expiration_days <= 3650
    error_message = "Old versions must be kept between 1 and 3650 days."
  }

  validation {
    condition     = var.advanced_settings.kms_key_arn == "" || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:(key|alias)/.+$", var.advanced_settings.kms_key_arn))
    error_message = "kms_key_arn must be empty or the ARN of a KMS key or alias."
  }

  validation {
    condition     = var.advanced_settings.log_retention_days >= 1 && var.advanced_settings.log_retention_days <= 3650
    error_message = "Access logs must be kept between 1 and 3650 days."
  }
}
