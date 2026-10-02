# Identity for the Acme Shop stack, hardened.
#
# Act 3's defense: the deploy role's policy is scoped to exactly what a
# pipeline deployment needs (read this stack's SSM parameters, fetch this
# stack's assets) instead of Action "*" on Resource "*". Contrast with
# ../../vulnerable/iam.tf.
#
# The emulator does NOT enforce IAM policies or trust documents, so the
# attack chain will still succeed at the API level here; on real AWS every
# wildcard call the catches-all would have allowed is denied. See the
# ceiling note in CLAUDE.md.

resource "aws_iam_user" "acme_ci" {
  name = "acme-ci-hardened"
}

resource "aws_iam_role" "deploy" {
  name = "acme-shop-deploy-hardened"
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

resource "aws_iam_role_policy" "deploy_scoped" {
  name = "deploy-scoped"
  role = aws_iam_role.deploy.id
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

resource "aws_iam_role" "runtime" {
  name = "acme-shop-runtime-hardened"
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