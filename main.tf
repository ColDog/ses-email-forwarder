# Required Variables:
variable "from_email" {
  description = "The email address to forward from."
}

variable "mapping" {
  type        = "map"
  description = "Email forward mapping containing an incoming email mapped to outgoing emails"
}

variable "name" {
  description = "Resource name"
}

# Optional Variables:

variable "recipients" {
  description = "Recipients are a list of email addresses to match"
  type        = "list"
  default     = []
}

variable "tags" {
  description = "Configurable tags for all AWS resources"
  type        = "map"
  default     = {}
}

# Resources:

resource "aws_s3_bucket" "emails" {
  bucket        = "${var.name}-emails"
  acl           = "private"
  tags          = "${var.tags}"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "emails"
    prefix  = "emails/"
    enabled = true

    expiration {
      days = 7
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "emails" {
  bucket = "${aws_s3_bucket.emails.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowSESPuts",
    "Effect": "Allow",
    "Principal": {
      "Service": "ses.amazonaws.com"
    },
    "Action": "s3:PutObject",
    "Resource": "arn:aws:s3:::${aws_s3_bucket.emails.id}/*",
    "Condition": {
      "StringEquals": {
        "aws:Referer": "${data.aws_caller_identity.current.account_id}"
      }
    }
  }]
}
EOF
}

data "template_file" "index" {
  template = "${file("${path.module}/index.js.tpl")}"

  vars {
    from_email    = "${var.from_email}"
    bucket        = "${aws_s3_bucket.emails.bucket}"
    bucket_prefix = "emails/"
    mapping       = "${jsonencode(var.mapping)}"
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/email-forwarder.zip"

  source {
    content  = "${data.template_file.index.rendered}"
    filename = "index.js"
  }

  source {
    content  = "${file("${path.module}/email-forwarder.js")}"
    filename = "email-forwarder.js"
  }
}

resource "aws_iam_role" "main_role" {
  name = "${var.name}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "main_role_policy" {
  name = "${var.name}-policy"
  role = "${aws_iam_role.main_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ses:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "arn:aws:s3:::${aws_s3_bucket.emails.id}/*"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "main" {
  filename         = "${data.archive_file.lambda.output_path}"
  function_name    = "${var.name}-function"
  role             = "${aws_iam_role.main_role.arn}"
  handler          = "index.handler"
  source_code_hash = "${sha256(data.archive_file.lambda.output_base64sha256)}"
  runtime          = "nodejs8.10"

  tags = "${var.tags}"
}

resource "aws_lambda_permission" "allow_ses" {
  statement_id   = "AllowExecutionFromSES"
  action         = "lambda:InvokeFunction"
  function_name  = "${aws_lambda_function.main.function_name}"
  principal      = "ses.amazonaws.com"
  source_account = "${data.aws_caller_identity.current.account_id}"
}

resource "aws_ses_receipt_rule" "main" {
  name          = "${var.name}"
  rule_set_name = "default-rule-set"
  recipients    = ["${var.recipients}"]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = "${aws_s3_bucket.emails.bucket}"
    object_key_prefix = "emails/"
    position          = 1
  }

  lambda_action {
    function_arn = "${aws_lambda_function.main.arn}"
    position     = 2
  }
}
