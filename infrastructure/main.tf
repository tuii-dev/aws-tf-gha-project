# Static Site is not the name of the bucket, its the name terraform uses 
# to track the resources
resource "aws_s3_bucket" "static_site" {
    bucket = var.bucket_name
}

# Configure the S3 bucket to serve static website content
# resource "aws_s3_bucket_website_configuration" "static_website_config" {
#     bucket = aws_s3_bucket.static_site.id

#     # The index document is the default document served when a user requests
#     # a URL that does not explicitly specify a document.
#     index_document {
#         suffix = "index.html"
#     }
# }

# Grant public read access to the S3 bucket
# resource "aws_s3_bucket_policy" "static_site_policy" {
#     bucket = aws_s3_bucket.static_site.id
#     policy = jsonencode({
#         Version = "2012-10-17"
#         Statement = [
#             {
#                 # Allow public read access to all objects in the bucket
#                 Effect    = "Allow"
#                 Principal = "*"
#                 Action    = "s3:GetObject"
#                 Resource  = "${aws_s3_bucket.static_site.arn}/*"
#             }
#         ]
#     })

#     # The bucket policy depends on the public access block, which must be
#     # created before the policy can be applied.
#     # Specifies a dependency between the bucket policy and the public access block
#     depends_on = [ aws_s3_bucket_public_access_block.static_site_access ]
# }

# Allow public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "static_site_access" {
    bucket = aws_s3_bucket.static_site.id

    # Allow public read access to the bucket
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}