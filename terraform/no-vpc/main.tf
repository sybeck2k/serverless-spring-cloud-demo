data "aws_caller_identity" "current" {}
data "aws_region" "current" {current = true}

resource "aws_sns_topic" "lambda_ipc" {
  name = "lambda-test-topic"
}

resource "aws_iam_role" "publisher" {
  name = "lambda-test-publisher"
  path = "/service-role/"

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

resource "aws_iam_role_policy" "publisher" {
  name = "lambdaPublishSNS"
  role = "${aws_iam_role.publisher.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda-publisher-name}:*"
            ]
        },
        {
            "Effect":"Allow",
            "Action":"sns:Publish",
            "Resource":"${aws_sns_topic.lambda_ipc.arn}"
        }
    ]
}
EOF
}

resource "aws_iam_role" "consumer" {
  name = "lambda-test-consumer"
  path = "/service-role/"

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

resource "aws_iam_role_policy" "consumer" {
  name = "lambdaConsumerSNS"
  role = "${aws_iam_role.consumer.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda-consumer-name}:*"
            ]
        }
    ]
}
EOF
}

resource "aws_lambda_function" "test_pusblisher" {
  filename         = "${var.lambda-jar}"
  function_name    = "${var.lambda-publisher-name}"
  role             = "${aws_iam_role.publisher.arn}"
  handler          = "org.springframework.cloud.function.adapter.aws.SpringBootStreamHandler"
  source_code_hash = "${base64sha256(file(var.lambda-jar))}"
  runtime          = "java8"
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      FUNCTION_NAME = "produceLog"
      SPRING_APPLICATION_JSON = "{\"sns\": {\"topicArn\": \"${aws_sns_topic.lambda_ipc.arn}\", \"region\": \"${data.aws_region.current.name}\"}}"
    }
  }
}

resource "aws_lambda_function" "test_consumer" {
  filename         = "${var.lambda-jar}"
  function_name    = "${var.lambda-consumer-name}"
  role             = "${aws_iam_role.consumer.arn}"
  handler          = "org.springframework.cloud.function.adapter.aws.SpringBootStreamHandler"
  source_code_hash = "${base64sha256(file(var.lambda-jar))}"
  runtime          = "java8"
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      FUNCTION_NAME = "countLogMessageLength"
    }
  }
}

resource "aws_sns_topic_subscription" "topic_lambda" {
  topic_arn = "${aws_sns_topic.lambda_ipc.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.test_consumer.arn}"
}

resource "aws_lambda_permission" "with_sns" {
  statement_id = "LambdaTestAllowExecutionFromSNS"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.test_consumer.arn}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.lambda_ipc.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_test_publisher" {
  statement_id = "LambdaTestAllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.test_pusblisher.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.every_minute.arn}"
}

resource "aws_cloudwatch_event_rule" "every_minute" {
  name = "every_minute"
  description = "Fires every minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "every_minute" {
  rule = "${aws_cloudwatch_event_rule.every_minute.name}"
  target_id = "every_minute"
  input = "{}"
  arn = "${aws_lambda_function.test_pusblisher.arn}"
}