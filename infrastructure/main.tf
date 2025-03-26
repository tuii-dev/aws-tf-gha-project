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

# The origin access control is used to configure the CloudFront distribution
# to use the S3 bucket as the origin.
resource "aws_cloudfront_origin_access_control" "oac" {
  # The name of the origin access control
  name                              = "oac-${aws_s3_bucket.static_site.bucket}"

  # The description of the origin access control
  description                       = "OAC for ${aws_s3_bucket.static_site.bucket}"

  # The type of origin access control
  origin_access_control_origin_type = "s3"

  # The signing behavior of the origin access control
  # Always sign requests to the origin
  signing_behavior                  = "always"

  # The signing protocol of the origin access control
  # Use the latest signing protocol
  signing_protocol                  = "sigv4"
}

# The CloudFront distribution is used to serve the static website
resource "aws_cloudfront_distribution" "s3_distribution" {
  # The origin of the distribution is the S3 bucket
  origin {
    # The domain name of the origin
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name

    # The origin access control ID
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id

    # The origin ID
    origin_id                = "S3-${aws_s3_bucket.static_site.bucket}"
  }

  # The distribution is enabled
  enabled             = true

  # The distribution is enabled for IPv6
  is_ipv6_enabled     = true

  # The comment of the distribution
  comment             = "CloudFront Distribution for ${aws_s3_bucket.static_site.bucket}"

  # The default root object of the distribution
  default_root_object = "index.html"

  # The aliases of the distribution
  aliases = ["keeperofthewatchfire.com", "www.keeperofthewatchfire.com"]

  # The default cache behavior of the distribution
  default_cache_behavior {
    # The allowed methods of the cache behavior
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]

    # The cached methods of the cache behavior
    cached_methods   = ["GET", "HEAD"]

    # The target origin ID of the cache behavior
    target_origin_id = "S3-${aws_s3_bucket.static_site.bucket}"

    # The forwarded values of the cache behavior
    forwarded_values {
      # The query string of the cache behavior
      query_string = false

      # The cookies of the cache behavior
      cookies {
        # The forward cookies of the cache behavior
        forward = "none"
      }
    }

    # The viewer protocol policy of the cache behavior
    viewer_protocol_policy = "redirect-to-https"

    # The minimum time to live of the cache behavior
    min_ttl                = 0

    # The default time to live of the cache behavior
    default_ttl            = 3600

    # The maximum time to live of the cache behavior
    max_ttl                = 86400
  }

  # The price class of the distribution
  price_class = "PriceClass_200"

  # The restrictions of the distribution
  restrictions {
    # The geo restriction of the distribution
    geo_restriction {
      # The restriction type of the geo restriction
      restriction_type = "none"
    }
  }

  # The tags of the distribution
  tags = {
    Environment = "production"
  }

  # The viewer certificate of the distribution
  viewer_certificate {
    # The ARN of the ACM certificate
    acm_certificate_arn = aws_acm_certificate.keeperofthewatchfire_certificate.arn

    # The SSL support method of the viewer certificate
    ssl_support_method  = "sni-only"
  }

  # The depends on of the distribution
  # The distribution depends on the ACM certificate validation
  depends_on = [aws_acm_certificate_validation.keeperofthewatchfire_cert_validation]
}

# The S3 bucket policy is used to grant public read access to the S3 bucket
resource "aws_s3_bucket_policy" "static_site_policy" {
    provider = aws.central1
    # The bucket of the policy
    bucket = aws_s3_bucket.static_site.id

    # The policy of the policy
    policy = jsonencode({
        # The version of the policy
        Version = "2012-10-17"

        # The statement of the policy
        Statement = [
            {
                # The action of the statement
                Action = "s3:GetObject"

                # The effect of the statement
                Effect = "Allow"

                # The resource of the statement
                Resource = "${aws_s3_bucket.static_site.arn}/*"

                # The principal of the statement
                Principal = {
                    Service = "cloudfront.amazonaws.com"
                }

                # The condition of the statement
                Condition = {
                    StringEquals = {
                        "aws:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
                    }
                }
            }
        ]
    })
}