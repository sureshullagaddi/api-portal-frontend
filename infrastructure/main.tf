data "aws_caller_identity" "current" {}

# ── Read backend API URL from SSM (published by api-portal-backend) ───────────
data "aws_ssm_parameter" "backend_api_url" {
  name = "/${var.project_name}/${var.environment}/backend/api-url"
}

locals {
  prefix        = "${var.project_name}-${var.environment}"
  frontend_dist = "${path.module}/../dist"
  mime_types = {
    ".html" = "text/html"
    ".js"   = "application/javascript"
    ".css"  = "text/css"
    ".json" = "application/json"
    ".ico"  = "image/x-icon"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".woff2" = "font/woff2"
    ".woff"  = "font/woff"
  }
}

# ── S3 bucket ─────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "frontend" {
  bucket = "${local.prefix}-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  index_document { suffix = "index.html" }
  error_document { key    = "index.html" }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })
}

# ── Upload React build artifacts ──────────────────────────────────────────────
resource "aws_s3_object" "react_build" {
  for_each = fileset(local.frontend_dist, "**/*")

  bucket       = aws_s3_bucket.frontend.id
  key          = each.value
  source       = "${local.frontend_dist}/${each.value}"
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), "application/octet-stream")
  etag         = filemd5("${local.frontend_dist}/${each.value}")

  # Cache JS/CSS assets aggressively (content-hashed by Vite)
  cache_control = can(regex("\\.(js|css)$", each.value)) ? "public, max-age=31536000, immutable" : "no-cache"
}

# ── config.js — runtime-injects backend API URL (no React rebuild needed) ─────
# Overwrites on every deploy to pick up backend URL changes.
resource "aws_s3_object" "config_js" {
  bucket        = aws_s3_bucket.frontend.id
  key           = "config.js"
  content_type  = "application/javascript"
  cache_control = "no-cache, no-store, must-revalidate"
  content       = "window.__CONFIG__ = { apiEndpoint: '${data.aws_ssm_parameter.backend_api_url.value}' };"
  etag          = md5(data.aws_ssm_parameter.backend_api_url.value)
}
