# Static Site is not the name of the bucket, its the name terraform uses 
# to track the resources
resource "aws_s3_bucket" "static_site" {
    bucket = var.bucket_name
}
    