# LocalStack-only variable values for this scenario, loaded by `make apply`
# (-var-file). Real-AWS runs simply omit this file: every variable below
# then keeps its plain-AWS default. See docs/aws-migration.md.
#
# NOTE: the "secret" values here are demo placeholders, fake by design
# (they are the payload Act 1 extracts from state on camera).

aws_endpoints = {
  s3             = "http://localhost:4566"
  dynamodb       = "http://localhost:4566"
  ec2            = "http://localhost:4566"
  iam            = "http://localhost:4566"
  ssm            = "http://localhost:4566"
  sts            = "http://localhost:4566"
  secretsmanager = "http://localhost:4566"
}

skip_aws_validation = true

db_password = "demo-only:Acme-db-pw-7f3D!fake"
api_key     = "demo-only:pk_live_FAKEACME000000ffaa"