# Identity for the Acme Shop stack.
#
# THIRD FLAW (Act 3): the deploy role used by CI has wildcard permissions,
# so whatever the pipeline authenticates as can reach production data
# owned by the narrow runtime role. In a real account the static CI
# identity would carry long-lived access keys, the kind that leak and
# start Act 1.

# Static CI identity. Long-lived access keys live out-of-band; in the
# attack story one pair leaked (see attack/act1/history-leak/).
resource "aws_iam_user" "acme_ci" {
  name = "acme-ci"
}

# The role the pipeline assumes for deployments. Deliberately over-broad:
# Action "*" on Resource "*" is the classic "CI needs everything" IAM
# shortcut. The hardened variant replaces this with scoped actions/resources.
resource "aws_iam_role" "deploy" {
  name = "acme-shop-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_user.acme_ci.arn }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "deploy_catch_all" {
  name = "deploy-catch-all"
  role = aws_iam_role.deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

# The role the app instance runs under. Narrow on purpose: it may only read
# its own parameters and its own asset bucket. This is what Act 3 pivots
# toward via the deploy role's wildcards.
resource "aws_iam_role" "runtime" {
  name = "acme-shop-runtime"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "runtime_read_own_params" {
  name = "runtime-read-own-params"
  role = aws_iam_role.runtime.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:*:*:parameter/prod/${local.shop_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.assets.arn}/*"
      }
    ]
  })
}
