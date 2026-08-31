resource "aws_s3_bucket" "terraform-state" {
  bucket        = "terraform-state"
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform-state.id
  versioning_configuration {
    status = "enabled"
  }
}
