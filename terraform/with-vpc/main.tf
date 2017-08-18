data "aws_caller_identity" "current" {}
data "aws_region" "current" {current = true}

//  Define the VPC.
resource "aws_vpc" "lambda-test" {
  cidr_block           = "${var.vpc_cidr}" // i.e. 10.0.0.0 to 10.0.255.255
  enable_dns_hostnames = true

  tags {
    Name    = "Lambda Test with Spring Cloud Function"
    Project = "lambda-test"
  }
}

//  Create an Internet Gateway for the VPC.
resource "aws_internet_gateway" "lambda-test" {
  vpc_id = "${aws_vpc.lambda-test.id}"

  tags {
    Name    = "Lambda Test IGW"
    Project = "lambda-test"
  }
}

resource "aws_subnet" "dmz_subnet" {
  vpc_id                  = "${aws_vpc.lambda-test.id}"
  cidr_block              = "${var.dmz_subnet}"
  availability_zone       = "${lookup(var.subnetaz1, data.aws_region.current.name)}"
  map_public_ip_on_launch = true
  depends_on              = ["aws_internet_gateway.lambda-test"]

  tags {
    Name    = "Lambda Test DMZ Subnet"
    Project = "lambda-test"
  }
}

//  Create a subnet for each AZ.
resource "aws_subnet" "subnet1" {
  vpc_id                  = "${aws_vpc.lambda-test.id}"
  cidr_block              = "${var.subnet1}"
  availability_zone       = "${lookup(var.subnetaz1, data.aws_region.current.name)}"
  map_public_ip_on_launch = true
  depends_on              = ["aws_internet_gateway.lambda-test"]

  tags {
    Name    = "Lambda Test Subnet 1"
    Project = "lambda-test"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = "${aws_vpc.lambda-test.id}"
  cidr_block              = "${var.subnet2}"
  availability_zone       = "${lookup(var.subnetaz2, data.aws_region.current.name)}"
  map_public_ip_on_launch = true
  depends_on              = ["aws_internet_gateway.lambda-test"]

  tags {
    Name    = "Lambda Test Subnet 2"
    Project = "lambda-test"
  }
}

//  Create a route table allowing all addresses access to the IGW.
resource "aws_route_table" "private" {
  vpc_id                  = "${aws_vpc.lambda-test.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat.id}"
  }

  tags {
    Name    = "Lambda Test Private Route Table"
    Project = "lambda-test"
  }
}

resource "aws_route_table" "dmz" {
  vpc_id = "${aws_vpc.lambda-test.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.lambda-test.id}"
  }

  tags {
    Name = "Lambda Test Private Route Table"
    Project = "lambda-test"
  }
}

//  Now associate the route table with the public subnet - giving
//  all subnet instances access to the internet.
resource "aws_route_table_association" "subnet1" {
  subnet_id      = "${aws_subnet.subnet1.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "subnet2" {
  subnet_id      = "${aws_subnet.subnet2.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "dmz" {
  subnet_id      = "${aws_subnet.dmz_subnet.id}"
  route_table_id = "${aws_route_table.dmz.id}"
}

resource "aws_main_route_table_association" "vpc_to_main_route" {
  vpc_id         = "${aws_vpc.lambda-test.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_eip" "nat-gw" {
  vpc      = true
  depends_on = ["aws_internet_gateway.lambda-test"]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat-gw.id}"
  subnet_id = "${aws_subnet.dmz_subnet.id}"
  depends_on = ["aws_internet_gateway.lambda-test"]
}

//  Create an internal security group for the VPC, which allows everything in the VPC
//  to talk to everything else.
resource "aws_security_group" "internal_connectivity" {
  name        = "internal-connectivity"
  description = "Default security group that allows inbound and outbound traffic from all instances in the VPC"
  vpc_id      = "${aws_vpc.lambda-test.id}"

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name    = "Lambda Test Internal VPC"
    Project = "lambda-test"
  }
}

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
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:AttachNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface"
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
        },
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:AttachNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface"
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

  vpc_config {
    security_group_ids = ["${aws_security_group.internal_connectivity.id}"]
    subnet_ids = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
  }

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

  vpc_config {
    security_group_ids = ["${aws_security_group.internal_connectivity.id}"]
    subnet_ids = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
  }

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