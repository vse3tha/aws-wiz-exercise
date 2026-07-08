resource "aws_s3_bucket" "mongo_backups" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "mongo_backups" {
  bucket = aws_s3_bucket.mongo_backups.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Intentional weakness: allow public bucket policies/reads/listing.
# If the lab account has account-level S3 Block Public Access enabled, this bucket policy will be blocked.
resource "aws_s3_bucket_public_access_block" "mongo_backups" {
  bucket = aws_s3_bucket.mongo_backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "mongo_backups_public" {
  statement {
    sid     = "PublicListBucketIntentionalWeakness"
    effect  = "Allow"
    actions = ["s3:ListBucket"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [aws_s3_bucket.mongo_backups.arn]
  }

  statement {
    sid     = "PublicReadObjectsIntentionalWeakness"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = ["${aws_s3_bucket.mongo_backups.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "mongo_backups_public" {
  bucket = aws_s3_bucket.mongo_backups.id
  policy = data.aws_iam_policy_document.mongo_backups_public.json

  depends_on = [aws_s3_bucket_public_access_block.mongo_backups]
}
