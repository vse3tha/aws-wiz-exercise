# Preventative cloud control: AWS WAFv2 attached to the ALB through Kubernetes Ingress annotation.
resource "aws_wafv2_web_acl" "app" {
  name        = "${var.project_name}-app-waf"
  description = "Lab WAF for the public ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${replace(var.project_name, "-", "")}-waf"
    sampled_requests_enabled   = true
  }
}

# Optional detective control: GuardDuty, including EKS audit log finding support.
# GuardDuty allows only one detector per account per Region and is often centrally managed/blocked in lab accounts.
# Defaults skip all GuardDuty API calls; enable only when your IAM/SCP allows GuardDuty management.
resource "aws_guardduty_detector" "this" {
  count  = var.create_guardduty_detector ? 1 : 0
  enable = true
}

locals {
  # Static plan-time switch. Do not derive resource count from aws_guardduty_detector.this[0].id,
  # because that ID is unknown until apply and causes "Invalid count argument".
  guardduty_manage_eks_audit_feature = var.enable_guardduty_eks_audit_feature && (var.create_guardduty_detector || var.existing_guardduty_detector_id != "")
}

resource "aws_guardduty_detector_feature" "eks_audit" {
  count = local.guardduty_manage_eks_audit_feature ? 1 : 0

  detector_id = var.create_guardduty_detector ? aws_guardduty_detector.this[0].id : var.existing_guardduty_detector_id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

# Detective control: AWS Config with managed rules that should flag two intentional weaknesses.
# AWS Config allows only one customer-managed recorder and one delivery channel per account per Region.
# If your lab account already has Config enabled, set create_config_recorder=false and keep enable_config_rules=true.
resource "aws_s3_bucket" "config" {
  count = var.create_config_recorder ? 1 : 0

  bucket        = "${var.project_name}-aws-config-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "config" {
  count = var.create_config_recorder ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count = var.create_config_recorder ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "config" {
  count = var.create_config_recorder ? 1 : 0

  name = "${var.project_name}-aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.create_config_recorder ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

data "aws_iam_policy_document" "config_bucket" {
  count = var.create_config_recorder ? 1 : 0

  statement {
    sid     = "AWSConfigBucketPermissionsCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl", "s3:ListBucket"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    resources = [aws_s3_bucket.config[0].arn]
  }

  statement {
    sid     = "AWSConfigBucketDelivery"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.config[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  count = var.create_config_recorder ? 1 : 0

  bucket = aws_s3_bucket.config[0].id
  policy = data.aws_iam_policy_document.config_bucket[0].json
}

resource "aws_config_configuration_recorder" "this" {
  count = var.create_config_recorder ? 1 : 0

  name     = "${var.project_name}-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = false
  }

  depends_on = [aws_iam_role_policy_attachment.config]
}

resource "aws_config_delivery_channel" "this" {
  count = var.create_config_recorder ? 1 : 0

  name           = "${var.project_name}-delivery"
  s3_bucket_name = aws_s3_bucket.config[0].bucket

  depends_on = [aws_s3_bucket_policy.config]
}

resource "aws_config_configuration_recorder_status" "this" {
  count = var.create_config_recorder ? 1 : 0

  name       = aws_config_configuration_recorder.this[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

resource "aws_config_config_rule" "s3_public_read" {
  count = var.enable_config_rules ? 1 : 0

  name = "${var.project_name}-s3-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

resource "aws_config_config_rule" "incoming_ssh_disabled" {
  count = var.enable_config_rules ? 1 : 0

  name = "${var.project_name}-incoming-ssh-disabled"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}
