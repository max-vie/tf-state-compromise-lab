# LocalStack-only values for the backend bootstrap. Real-AWS runs omit
# this file; see ../../../docs/aws-migration.md.

aws_endpoints = {
  s3       = "http://localhost:4566"
  dynamodb = "http://localhost:4566"
}

skip_aws_validation = true