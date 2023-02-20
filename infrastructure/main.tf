
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


  ttl {
    attribute_name = "TimeToExist"
    enabled        = false
  }

  tags = {
    Project = "alexandria"
  }
}

# Here we grab the compiled executable and use the archive_file package
# to convert it into the .zip file we need.
data "archive_file" "lambda_writer_archive" {
  type        = "zip"
  source_file = var.lambda_writer_bin_path
  output_path = "writer.zip"
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "alexandria_lambda_role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Here we attach a permission to execute a lambda function to our role
resource "aws_iam_role_policy_attachment" "alexandria_lambda_execution_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



// Add lambda -> DynamoDB policies to the lambda execution role
resource "aws_iam_role_policy" "lambda_db_policy" {

  # Set depends on to make sure dtaabase create before getting the arn
  depends_on = [
    aws_dynamodb_table.library_database
  ]
  name = "lambda_lambda_db_policy"
  role = aws_iam_role.lambda_role.name
  policy = jsonencode(
    {
      "Version" = "2012–10–17",
      "Statement" = [
        {
          "Sid" = "SpecificTable",
          "Action" = [
            "dynamodb:PutItem",
            "dynamodb:Scan"
          ],
          "Effect"   = "Allow",
          "Resource" = "${aws_dynamodb_table.library_database.arn}"
        }
      ]
    }
  )
}


# Here is the definition of our lambda function 
resource "aws_lambda_function" "writer_lambda" {
  function_name    = "LambdaWriter"
  source_code_hash = data.archive_file.lambda_writer_archive.output_base64sha256
  filename         = data.archive_file.lambda_writer_archive.output_path
  handler          = "func"
  runtime          = "provided"

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
