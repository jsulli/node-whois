provider "aws" {
  region = "us-east-1"
}


data "archive_file" "lambda" {
  source_file = "dist/bundle.js"
  type = "zip"
  output_path = "whois.zip"
}


resource "aws_lambda_function" "lambda-whois" {
  # The local file to upload to lambda
  filename = "whois.zip"

  # Lambda function name
  function_name = "lambda-whois"

  # The entrypoint to the lambda function in the source code.  The format is <file-name>.<property-name>
  handler = "bundle.handler"

  # IAM policy for the lambda function.
  role = "${aws_iam_role.lambda-role.arn}"

  # Set runtime for lambda function
  runtime = "nodejs8.10"

  # Check the hash on the zip file to see if it has changed. If it changed, Terraform will re-upload the zip to lambda
  source_code_hash = "${base64sha256(file("whois.zip"))}"
}


# Set permissions on the lambda function, allowing API Gateway to invoke the function
resource "aws_lambda_permission" "allow_api_gateway" {
  # The action this permission allows is to invoke the function
  action = "lambda:InvokeFunction"

  # The name of the lambda function to attach this permission to
  function_name = "${aws_lambda_function.lambda-whois.arn}"

  # An optional identifier for the permission statement
  statement_id = "AllowExecutionFromApiGateway"

  # The item that is getting this lambda permission
  principal = "apigateway.amazonaws.com"

  # /*/*/* sets this permission for all stages, methods, and resource paths in API Gateway to the lambda
  # function. - https://bit.ly/2NbT5V5
  source_arn = "${aws_api_gateway_rest_api.whois-api.execution_arn}/*/*/*"
}


# Create an IAM role for the lambda function
resource "aws_iam_role" "lambda-role" {
  name = "iam-lambda-role"
  assume_role_policy = "${file("lambdaRole.json")}"
}


# Declare a new API Gateway REST API
resource "aws_api_gateway_rest_api" "whois-api" {
  # The name of the REST API
  name = "whoisAPI"

  # An optional description of the REST API
  description = "A REST API for getting information on a web address"
}

# Create an API Gateway resource, which is a certain path inside the REST API
resource "aws_api_gateway_resource" "whois-api-resource" {
  # The id of the associated REST API and parent API resource are required
  rest_api_id = "${aws_api_gateway_rest_api.whois-api.id}"
  parent_id = "${aws_api_gateway_rest_api.whois-api.root_resource_id}"

  # The last segment of the URL path for this API resource
  path_part = "whois"
}

resource "aws_api_gateway_resource" "address-api-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.whois-api.id}"
  parent_id = "${aws_api_gateway_resource.whois-api-resource.id}"

  path_part = "{address}"
}

# Provide an HTTP method to a API Gateway resource (REST endpoint)
resource "aws_api_gateway_method" "whois-method" {
  # The ID of the REST API and the resource at which the API is invoked
  rest_api_id = "${aws_api_gateway_rest_api.whois-api.id}"
  resource_id = "${aws_api_gateway_resource.address-api-resource.id}"

  # The verb of the HTTP request
  http_method = "GET"

  # Whether any authentication is needed to call this endpoint
  authorization = "NONE"
}


# Integrate API Gateway REST API with a Lambda function
resource "aws_api_gateway_integration" "lambda-api-integration" {
  # The ID of the REST API and the endpoint at which to integrate a Lambda function
  rest_api_id = "${aws_api_gateway_rest_api.whois-api.id}"
  resource_id = "${aws_api_gateway_resource.address-api-resource.id}"

  # The HTTP method to integrate with the Lambda function
  http_method = "${aws_api_gateway_method.whois-method.http_method}"

  # AWS is used for Lambda proxy integration when you want to use a Velocity template
  type = "AWS"

  # The URI at which the API is invoked
  uri = "${aws_lambda_function.lambda-whois.invoke_arn}"

  # Lambda functions can only be invoked via HTTP POST - https://amzn.to/2owMYNh
  integration_http_method = "POST"

  # Configure the Velocity request template for the application/json MIME type
  request_templates {
    "application/json" = "${file("request.vm")}"
  }
}

# Set CORS access parameters on the gateway
module "cors" {
  source = "github.com/squidfunk/terraform-aws-api-gateway-enable-cors"
  version = "0.2.0"

  api_id          = "${aws_api_gateway_rest_api.whois-api.id}"
  api_resource_id = "${aws_api_gateway_resource.address-api-resource.id}"
}


# Create an HTTP method response for the aws lambda integration
resource "aws_api_gateway_method_response" "lambda-api-method-response" {
  rest_api_id = "${aws_api_gateway_rest_api.whois-api.id}"
  resource_id = "${aws_api_gateway_resource.address-api-resource.id}"
  http_method = "${aws_api_gateway_method.whois-method.http_method}"
  status_code = "200"
}

# Configure the API Gateway and Lambda functions response
resource "aws_api_gateway_integration_response" "lambda-api-integration-response" {
  rest_api_id = "${aws_api_gateway_rest_api.whois-api.id}"
  resource_id = "${aws_api_gateway_resource.address-api-resource.id}"
  http_method = "${aws_api_gateway_method.whois-method.http_method}"

  status_code = "${aws_api_gateway_method_response.lambda-api-method-response.status_code}"

  # Configure the Velocity response template for the application/json MIME type
  response_templates {
    "application/json" = "${file("response.vm")}"
  }

  # Remove race condition where the integration response is built before the lambda integration
  depends_on = [
    "aws_api_gateway_integration.lambda-api-integration"
  ]
}

# Create a new API Gateway deployment
resource "aws_api_gateway_deployment" "whois-api-dev-deployment" {
  rest_api_id = "${aws_api_gateway_rest_api.whois-api.id}"

  # development stage
  stage_name = "dev"

  # Remove race conditions - deployment should always occur after lambda integration
  depends_on = [
    "aws_api_gateway_integration.lambda-api-integration",
    "aws_api_gateway_integration_response.lambda-api-integration-response"
  ]
}

# URL to invoke the API
output "url" {
  value = "${aws_api_gateway_deployment.whois-api-dev-deployment.invoke_url}"
}