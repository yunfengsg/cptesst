locals {
    env           = "nonprod"                                      # Need to update prod or non-prod
    name_prefix   = "grp3" # your base name prefix
    env_suffix    = "-${local.env}"                                # always suffix the env
  }

## shopFloorData Lambda Execution Role ##

resource "aws_iam_policy" "shopFloorData_lambda_policy_lab2" {
  name        = "shopFloorData_lambda_policy_lab2${local.env_suffix}"       #local.env_suffix added
  path        = "/"
  description = "Policy to be attached to ShopFloorData_TxnService lambda"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "logs:*",
          "dynamodb:*"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role" "shopFloorData_lambda_role_lab2" {
  name = "shopFloorData_lambda_role_lab2${local.env_suffix}"       #local.env_suffix added

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

resource "aws_iam_role_policy_attachment" "shopFloorData_lambda_role_attach" {
  role       = aws_iam_role.shopFloorData_lambda_role_lab2.name
  policy_arn = aws_iam_policy.shopFloorData_lambda_policy_lab2.arn
}

## shopFloorData Lambda Fucntion ##

data "archive_file" "lambdadata" {
  type        = "zip"
  source_file = "${path.module}/lambdaData/shopFloorData/index2.js"
  output_path = "shopFloorData.zip"
}

resource "aws_lambda_function" "shopFloorData_txnService" {
  function_name = "ShopFloorData_TxnService${local.env_suffix}"       #local.env_suffix added
  role          = aws_iam_role.shopFloorData_lambda_role_lab2.arn
  runtime       = "nodejs16.x"
  filename      = "shopFloorData.zip"
  handler       = "index.handler"
  timeout       = "15"

  source_code_hash = data.archive_file.lambdadata.output_base64sha256

  # Enable X-Ray tracing
  tracing_config { # tschui added to solve the severity issue detected by Snyk
    mode = "Active"
  }
}

## AWI API Gateway ##

resource "aws_api_gateway_rest_api" "shopFloor_api_gw" {
  name        = "shopFloor_api_gw${local.env_suffix}"
  description = "REST API to CRUD Shop Floor Data"
}

resource "aws_api_gateway_resource" "shopFloor_resource" {
  rest_api_id = aws_api_gateway_rest_api.shopFloor_api_gw.id
  parent_id   = aws_api_gateway_rest_api.shopFloor_api_gw.root_resource_id
  path_part   = "shopFloorData"
}

## Post HTTP Method #

resource "aws_api_gateway_method" "post_shopFloor_data" {
  rest_api_id   = aws_api_gateway_rest_api.shopFloor_api_gw.id
  resource_id   = aws_api_gateway_resource.shopFloor_resource.id
  http_method   = "POST"
  #authorization = "NONE"
  authorization = "AWS_IAM" # tschui changed to solve the severity issue detected by Snyk
}

resource "aws_api_gateway_method_response" "post_shopFloor_data_response_200" {
  rest_api_id = aws_api_gateway_rest_api.shopFloor_api_gw.id
  resource_id = aws_api_gateway_resource.shopFloor_resource.id
  http_method = aws_api_gateway_method.post_shopFloor_data.http_method
  status_code = 200

  /**
   * This is where the configuration for CORS enabling starts.
   * We need to enable those response parameters and in the 
   * integration response we will map those to actual values
   */
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = true,
    "method.response.header.Access-Control-Allow-Methods"     = true,
    "method.response.header.Access-Control-Allow-Origin"      = true,
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration" "integration_post_shopFloor_data" {
  rest_api_id             = aws_api_gateway_rest_api.shopFloor_api_gw.id
  resource_id             = aws_api_gateway_resource.shopFloor_resource.id
  http_method             = aws_api_gateway_method.post_shopFloor_data.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.shopFloorData_txnService.invoke_arn
}

## Get HTTP Method ##

resource "aws_api_gateway_method" "get_shopFloor_data" {
  rest_api_id   = aws_api_gateway_rest_api.shopFloor_api_gw.id
  resource_id   = aws_api_gateway_resource.shopFloor_resource.id
  http_method   = "GET"
  #authorization = "NONE"
  authorization = "AWS_IAM" # tschui changed to solve the severity issue detected by Snyk
  request_parameters = {
    "method.request.querystring.Plant" = true,
    "method.request.querystring.Line"  = true
  }
}

resource "aws_api_gateway_method_response" "get_shopFloor_data_response_200" {
  rest_api_id = aws_api_gateway_rest_api.shopFloor_api_gw.id
  resource_id = aws_api_gateway_resource.shopFloor_resource.id
  http_method = aws_api_gateway_method.get_shopFloor_data.http_method
  status_code = 200

  /**
   * This is where the configuration for CORS enabling starts.
   * We need to enable those response parameters and in the 
   * integration response we will map those to actual values
   */
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = true,
    "method.response.header.Access-Control-Allow-Methods"     = true,
    "method.response.header.Access-Control-Allow-Origin"      = true,
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration" "integration_get_shopFloor_data" {
  rest_api_id             = aws_api_gateway_rest_api.shopFloor_api_gw.id
  resource_id             = aws_api_gateway_resource.shopFloor_resource.id
  http_method             = aws_api_gateway_method.get_shopFloor_data.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.shopFloorData_txnService.invoke_arn
}

## Delete HTTP Method ##

resource "aws_api_gateway_method" "delete_shopFloor_data" {
  rest_api_id   = aws_api_gateway_rest_api.shopFloor_api_gw.id
  resource_id   = aws_api_gateway_resource.shopFloor_resource.id
  http_method   = "DELETE"
  #authorization = "NONE"
  authorization = "AWS_IAM" # tschui changed to solve the severity issue detected by Snyk 
  request_parameters = {
    "method.request.querystring.Plant"   = true,
    "method.request.querystring.Line"    = true,
    "method.request.querystring.KpiName" = true
  }
}

resource "aws_api_gateway_method_response" "delete_shopFloor_data_response_200" {
  rest_api_id = aws_api_gateway_rest_api.shopFloor_api_gw.id
  resource_id = aws_api_gateway_resource.shopFloor_resource.id
  http_method = aws_api_gateway_method.delete_shopFloor_data.http_method
  status_code = 200

  /**
   * This is where the configuration for CORS enabling starts.
   * We need to enable those response parameters and in the 
   * integration response we will map those to actual values
   */
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = true,
    "method.response.header.Access-Control-Allow-Methods"     = true,
    "method.response.header.Access-Control-Allow-Origin"      = true,
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration" "integration_delete_shopFloor_data" {
  rest_api_id             = aws_api_gateway_rest_api.shopFloor_api_gw.id
  resource_id             = aws_api_gateway_resource.shopFloor_resource.id
  http_method             = aws_api_gateway_method.delete_shopFloor_data.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.shopFloorData_txnService.invoke_arn
}


## shopFloorData Lambda Function ##

resource "aws_lambda_permission" "shopFloorData_apigw_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.shopFloorData_txnService.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.shopFloor_api_gw.execution_arn}/*"
}

module "cors" {
  source = "./modules/cors"

  api_id            = aws_api_gateway_rest_api.shopFloor_api_gw.id
  api_resource_id   = aws_api_gateway_resource.shopFloor_resource.id
  allow_credentials = true
}

resource "aws_api_gateway_deployment" "shopFloorData_api_deploy" {
  rest_api_id = aws_api_gateway_rest_api.shopFloor_api_gw.id
  triggers = {
    redeployment = sha1(jsonencode([

      aws_api_gateway_resource.shopFloor_resource,
      aws_api_gateway_method.post_shopFloor_data,
      aws_api_gateway_integration.integration_post_shopFloor_data,
      aws_api_gateway_method.get_shopFloor_data,
      aws_api_gateway_integration.integration_get_shopFloor_data,
      aws_api_gateway_method.delete_shopFloor_data,
      aws_api_gateway_integration.integration_delete_shopFloor_data,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" { // tschui added to solve the severity issue detected by Snyk
  name              =  "/aws/api/gateway/logs${local.env_suffix}"          #local.env_suffix added
  retention_in_days = 30
}

resource "aws_api_gateway_stage" "stage-andon-api" {
  deployment_id = aws_api_gateway_deployment.shopFloorData_api_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.shopFloor_api_gw.id
  stage_name    = "dev"

   # Enabling X-Ray tracing
  xray_tracing_enabled = true # tschui added to solve the severity issue detected by Snyk

  # Enabling Access Logging
  access_log_settings { # tschui added to solve the severity issue detected by Snyk
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format          = "$context.requestId - $context.identity.sourceIp - $context.identity.userAgent - $context.requestTime - $context.status"
  }
}

