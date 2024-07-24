terraform{
    required_providers{
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.16"
        }
    }
}

provider "aws" {
    region = "us-east-1"
}

resource "aws_dynamodb_table" "resume_table" {
    name           = "Resumes"
    hash_key       = "ResumeId"
    read_capacity = 1
    write_capacity = 1

    attribute {
        name = "ResumeId"
        type = "S"
    }

   

  tags = {
    Name        = "dynamodb-table-1"
    Environment = "production"
  }
}

resource "aws_lambda_function" "resume_serverless_Api" {
  filename = "./lambda-function/resume-fetch.zip"
  source_code_hash = filebase64sha256("./lambda-function/resume-fetch.zip")
  function_name = "Resume_serverless_Api"
  handler = "index.handler"
  runtime = "nodejs16.x"
  role = aws_iam_role.lambda_exec_role.arn
  environment {
    variables = {
        DYNAMODB_TABLE = aws_dynamodb_table.resume_table.name
        }
    }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "IAM policy for Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = ["dynamodb:GetItem", "dynamodb:Scan", "dynamodb:Query", "dynamodb:UpdateItem", "dynamodb:PutItem"],
      Effect   = "Allow",
      Resource = "arn:aws:dynamodb:*:*:table/Resumes"
    },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_api_gateway_rest_api" "resume_api" {
  name        = "ResumeAPI"
  description = "API to get the latest resume data"
}

resource "aws_api_gateway_resource" "resume_resource" {
  rest_api_id = aws_api_gateway_rest_api.resume_api.id
  parent_id   = aws_api_gateway_rest_api.resume_api.root_resource_id
  path_part   = "resume"
}

resource "aws_api_gateway_method" "get_resume" {
  rest_api_id   = aws_api_gateway_rest_api.resume_api.id
  resource_id   = aws_api_gateway_resource.resume_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.resume_api.id
  resource_id = aws_api_gateway_resource.resume_resource.id
  http_method = aws_api_gateway_method.get_resume.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = aws_lambda_function.resume_serverless_Api.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.resume_api.id
  stage_name  = "prod"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resume_serverless_Api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.resume_api.execution_arn}/*/*"
}

output "api_id" {
  value = aws_api_gateway_rest_api.resume_api.id
}
output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.resume_api.id}.execute-api.us-east-1.amazonaws.com/${aws_api_gateway_deployment.api_deployment.stage_name}/resume?id=1"
}