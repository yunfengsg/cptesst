locals {
    env           = "nonprod-yyf"                                      # Need to update prod or non-prod
    name_prefix   = "grp3" # your base name prefix
    env_suffix    = "-${local.env}"                                # always suffix the env 
  }

##SES##

resource "aws_ses_email_identity" "source_alert_email" {
  email = "yunfengsg@gmail.com"
}

resource "aws_ses_email_identity" "delivery_alert_email" {
  email = "yunfengsg@gmail.com"
}

## shopFloorAlert Lambda Execution Role ##

resource "aws_iam_policy" "shopFloorAlert_lambda_policy_lab1" {
  name        = "shopFloorAlert_lambda_policy_lab1${local.env_suffix}"       #local.env_suffix added
  path        = "/"
  description = "Policy to be attached to lambda"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "ses:*",
          "logs:*",
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams",
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role" "shopFloorAlert_lambda_role_lab1" {
  name = "shopFloorAlert_lambda_role_lab1${local.env_suffix}"       #local.env_suffix added  

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

resource "aws_iam_role_policy_attachment" "shopFloorAlert_lambda_role_attach" {
  role       = aws_iam_role.shopFloorAlert_lambda_role_lab1.name
  policy_arn = aws_iam_policy.shopFloorAlert_lambda_policy_lab1.arn
}

## shopFloorAlert Lambda Function ##

data "archive_file" "lambdaalert" {
  type        = "zip"
  source_file = "${path.module}/lambdaAlert/sendAlertEmail/index1.js"
  output_path = "sendAlertEmail.zip"
}

resource "aws_lambda_function" "send_alert_email" {
  function_name = "SendAlertEmail${local.env_suffix}"               #local.env_suffix added
  role          = aws_iam_role.shopFloorAlert_lambda_role_lab1.arn
  runtime       = "nodejs16.x"
  filename      = "sendAlertEmail.zip"
  handler       = "index.handler"
  timeout       = "15"

  source_code_hash = data.archive_file.lambdaalert.output_base64sha256
  
  # Enable X-Ray tracing
  tracing_config { # tschui added to solve the severity issue detected by Snyk
    mode = "Active"
  }
}

##dynamodb##

resource "aws_kms_key" "shop_floor_alerts_kms" { # tschui added to solve the severity issue detected by Snyk
  description         = "KMS key for ${local.env} shop_floor_alerts DynamoDB table"
  enable_key_rotation = true
}

resource "aws_dynamodb_table" "shop_floor_alerts" {
  name             = "shop_floor_alerts${local.env_suffix}"     #local.env_suffix added
  billing_mode     = "PROVISIONED"
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
  read_capacity    = 5
  write_capacity   = 5
  hash_key         = "PK"
  range_key        = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }

  point_in_time_recovery { # tschui added to solve the severity issue detected by Snyk
    enabled = true         # Enable Point-in-Time Recovery (PITR)
  }  

  # Enable server-side encryption with customer-managed KMS key
  server_side_encryption { # tschui added to solve the severity issue detected by Snyk
    enabled     = true
    kms_key_arn = aws_kms_key.shop_floor_alerts_kms.arn
  }
}

resource "null_resource" "delay" {
  provisioner "local-exec" {
    command = "sleep 30" # Wait for 30 seconds
  }
}

resource "aws_lambda_event_source_mapping" "trigger" {

  batch_size        = 100
  event_source_arn  = aws_dynamodb_table.shop_floor_alerts.stream_arn
  function_name     = aws_lambda_function.send_alert_email.arn
  starting_position = "LATEST"

 depends_on = [null_resource.delay]
 
}




