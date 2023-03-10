
provider "aws" {

}


data "aws_caller_identity" "current" {}


resource "aws_dynamodb_table" "library_database" {
  name           = "LibraryOfAlexandria"
  billing_mode   = "PROVISIONED"
  read_capacity  = 15
  write_capacity = 15
  hash_key       = "category"
  range_key      = "itemURL"

  attribute {
    name = "itemURL"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  tags = {
    Project = "alexandria"
  }
}

# Here we grab the compiled executable and use the archive_file package
# to convert it into the .zip file we need.
# We need to use the null_resource to trigger creation during apply

resource "null_resource" "dummy_trigger" {
  triggers = {
    timestamp = timestamp()
  }
}

data "archive_file" "lambda_alexandria_archive" {
  type        = "zip"
  source_file = "${path.module}/lambda-bin/bootstrap"
  output_path = "${path.module}/alexandria.zip"
  depends_on = [
    null_resource.dummy_trigger
  ]
}

output "files" {
  value = fileset(path.module, "*")
}

data "aws_iam_policy_document" "lambda_assume_role_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


data "aws_iam_policy_document" "lambda_dynamodb_policy_document" {

  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:Scan"
    ]
    effect    = "Allow"
    resources = [aws_dynamodb_table.library_database.arn]

  }
}


resource "aws_iam_role" "lambda_role" {
  name = "alexandria_lambda_role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy_document.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  inline_policy {
    name   = "alexandria_dynamodb_policy"
    policy = data.aws_iam_policy_document.lambda_dynamodb_policy_document.json
  }
}

# Here is the definition of our lambda function 
resource "aws_lambda_function" "alexandria_lambda" {
  function_name    = "Lambda_alexandria"
  source_code_hash = data.archive_file.lambda_alexandria_archive.output_base64sha256
  filename         = data.archive_file.lambda_alexandria_archive.output_path
  handler          = "func"
  runtime          = "provided.al2"
  architectures    = ["arm64"]

  # here we enable debug logging for our Rust run-time environment. We would change
  # this to something less verbose for production.
  environment {
    variables = {
      "RUST_LOG" = "debug"
    }
  }

  #This attaches the role defined above to this lambda function
  role = aws_iam_role.lambda_role.arn
}
