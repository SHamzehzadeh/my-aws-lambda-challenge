# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1" 
}

# Create an S3 bucket
resource "aws_s3_bucket" "word_count_bucket" {
  bucket = "tech-chall-bucket"

}
resource "aws_s3_bucket_acl" "word_count_acl" {
  bucket = aws_s3_bucket.word_count_bucket.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]

}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.word_count_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}
# Enable versioning (optional but recommended for production)
resource "aws_s3_bucket_versioning" "versioning_word_count_bucket" {
  bucket = aws_s3_bucket.word_count_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda_word_count_role"

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

# Attach policy to allow S3 access
resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Create the Lambda function
resource "aws_lambda_function" "word_count_function" {
  function_name = "word_count_function"
  handler       = "index.lambda_handler" # Python file is named index.py
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role.arn

  # Zip file has been created - (zip lambda_funcion.zip index.py)
  filename = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip") 

  # Configure environment variables (if needed)
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.word_count_bucket.id
    }
  }
}

# Create an API Gateway REST API
resource "aws_api_gateway_rest_api" "word_count_api" {
  name        = "word_count_api"
  description = "API for word count"
}

# Create a resource for the POST endpoint
resource "aws_api_gateway_resource" "word_count_resource" {
  rest_api_id = aws_api_gateway_rest_api.word_count_api.id
  parent_id   = aws_api_gateway_rest_api.word_count_api.root_resource_id
  path_part   = "wordcount"
}

# Integrate API Gateway with Lambda

resource "aws_api_gateway_method" "word_count_method" {
  rest_api_id     = aws_api_gateway_rest_api.word_count_api.id
  resource_id     = aws_api_gateway_resource.word_count_resource.id
  http_method     = "GET"
  authorization   = "NONE"
}

resource "aws_api_gateway_integration" "word_count_integration" {
  rest_api_id              = aws_api_gateway_rest_api.word_count_api.id
  resource_id              = aws_api_gateway_resource.word_count_resource.id
  http_method              = aws_api_gateway_method.word_count_method.http_method
  integration_http_method  = "POST"
  type                     = "AWS_PROXY"
  uri                      = aws_lambda_function.word_count_function.invoke_arn
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role" {
  name               = "myrole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


# Grant API Gateway permission to invoke Lambda

resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.word_count_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.word_count_api.execution_arn}/*/*"
}
