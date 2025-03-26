# Static Site is not the name of the bucket, its the name terraform uses 
# to track the resources
resource "aws_s3_bucket" "static_site" {
    provider = aws.central1
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
    provider = aws.central1

    # Allow public read access to the bucket
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_acm_certificate" "keeperofthewatchfire_certificate" {
    domain_name = "keeperofthewatchfire.com"
    validation_method = "DNS"

    subject_alternative_names = ["www.keeperofthewatchfire.com"]

    tags = {
        Name = "keeperofthewatchfire.com SSL Certificate"
    }

    lifecycle {
        create_before_destroy = true
    }
}

# Get the route53 zone for the domain
data "aws_route53_zone" "domain_zone" {
    name = "keeperofthewatchfire.com"
}

# Create the certificate validation records
resource "aws_route53_record" "keeperofthewatchfire_cer_validation" {
    for_each = {
        for dvo in aws_acm_certificate.keeperofthewatchfire_certificate.domain_validation_options : dvo.domain_name
        => {
            name   = dvo.resource_record_name
            record = dvo.resource_record_value
            type   = dvo.resource_record_type
        }
    }

    # The name of the record to create
    name    = each.value.name

    # The value of the record
    records = [each.value.record]

    # The time to live of the record in seconds
    ttl     = 60

    # The type of record to create
    type    = each.value.type
    zone_id = data.aws_route53_zone.domain_zone.zone_id
}

# After creating the certificate validation records, validate the certificate
resource "aws_acm_certificate_validation" "keeperofthewatchfire_cert_validation" {
    # The ARN of the certificate to validate
    certificate_arn         = aws_acm_certificate.keeperofthewatchfire_certificate.arn

    # The fully qualified domain names of the validation records
    # This is a list of the FQDNs of the records created above
    validation_record_fqdns = [for record in aws_route53_record.keeperofthewatchfire_cer_validation : record.fqdn]
}


    