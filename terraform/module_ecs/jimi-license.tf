variable "license_name" {
    description = "The name of the license file"
    type        = string
    default     = "jimi-license.lic"
}

resource "aws_s3_bucket" "license_bucket" {
  bucket = "jimi-license-bucket"
}

resource "aws_s3_bucket_ownership_controls" "license_bucket" {
  bucket = aws_s3_bucket.license_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "license_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.license_bucket]
  bucket = aws_s3_bucket.license_bucket.id
  acl    = "private"
}

resource "aws_s3_object" "license_file" {
  bucket = aws_s3_bucket.license_bucket.bucket
  key    = var.license_name
  source = "/Users/ab/Downloads/${var.license_name}"
  acl    = "private"
}

locals {
  license_s3_location = "${aws_s3_bucket.license_bucket.bucket}/${var.license_name}"
}

resource "aws_iam_policy" "s3_read_license_policy" {
  name        = "s3_read_license_policy"
  description = "Allow ECS tasks to read license file from S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:GetObject"],
        Resource = ["${aws_s3_bucket.license_bucket.arn}/${var.license_name}"],
        Effect   = "Allow",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "s3_read_license_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.s3_read_license_policy.arn
}
