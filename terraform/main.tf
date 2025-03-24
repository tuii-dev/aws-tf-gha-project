resource "aws_s3_bucket" "static_site" {
  bucket = var.bucket_name
}

# resource "aws_s3_bucket_website_configuration" "static_website_config" {
#   bucket = aws_s3_bucket.static_site.id

#   index_document {
#     suffix = "index.html"
#   }
# }

resource "aws_s3_bucket_public_access_block" "static_site_access" {
  bucket                  = aws_s3_bucket.static_site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# resource "aws_s3_bucket_policy" "static_site_policy" {
#   bucket = aws_s3_bucket.static_site.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect    = "Allow"
#         Principal = "*"
#         Action    = "s3:GetObject"
#         Resource  = "${aws_s3_bucket.static_site.arn}/*"
#       }
#     ]
#   })

#   depends_on = [ aws_s3_bucket_public_access_block.static_site_access ]
# }

resource "aws_acm_certificate" "ehsanshekari_cert" {
  domain_name       = "ehsanshekari.com"
  validation_method = "DNS"

  subject_alternative_names = ["www.ehsanshekari.com"]

  tags = {
    Name = "ehsanshekari.com SSL Certificate"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "domain_zone" {
  name = "ehsanshekari.com"
}

resource "aws_route53_record" "ehsanshekari_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ehsanshekari_cert.domain_validation_options : dvo.domain_name
    => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  name    = each.value.name
  records = [each.value.record]
  ttl     = 60
  type    = each.value.type
  zone_id = data.aws_route53_zone.domain_zone.zone_id
}

resource "aws_acm_certificate_validation" "ehsanshekari_cert_validation" {
  certificate_arn         = aws_acm_certificate.ehsanshekari_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.ehsanshekari_cert_validation : record.fqdn]
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "oac-${aws_s3_bucket.static_site.bucket}"
  description                       = "OAC for ${aws_s3_bucket.static_site.bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "S3-${aws_s3_bucket.static_site.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront Distro for ${aws_s3_bucket.static_site.bucket}"
  default_root_object = "index.html"

  aliases = ["ehsanshekari.com", "www.ehsanshekari.com"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_site.bucket}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.ehsanshekari_cert.arn
    ssl_support_method  = "sni-only"
  }

  depends_on = [aws_acm_certificate_validation.ehsanshekari_cert_validation]
}

resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_route53_record" "ehsanshekari_root" {
  zone_id = data.aws_route53_zone.domain_zone.zone_id
  name    = "ehsanshekari.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ehsanshekari_www" {
  zone_id = data.aws_route53_zone.domain_zone.zone_id
  name    = "www.ehsanshekari.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
