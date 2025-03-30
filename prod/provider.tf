
/*
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "ap-southeast-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true


  endpoints {

    iot        = "http://localhost:4566"
    sqs        = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    dynamodb   = "http://localhost:4566"
    ses        = "http://localhost:4566"
    apigateway = "http://localhost:4566"

  }

}

*/

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"

  # Use LocalStack settings if USE_LOCALSTACK is true
  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      iot        = "http://localhost:4566"
      sqs        = "http://localhost:4566"
      lambda     = "http://localhost:4566"
      dynamodb   = "http://localhost:4566"
      ses        = "http://localhost:4566"
      apigateway = "http://localhost:4566"
    }
  }

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
}

variable "use_localstack" {
  type    = bool
  default = false
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}


