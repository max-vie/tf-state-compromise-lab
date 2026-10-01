# App-server resources: the stage for the demo, kept minimal.

# Asset bucket.
resource "aws_s3_bucket" "assets" {
  bucket = "${local.shop_name}-assets"
}

# App server: a single instance. The emulator accepts any AMI id; on real AWS
# swap in an actual AMI per region (docs/aws-migration.md).
resource "aws_instance" "app" {
  ami           = "ami-0c7217cd0039f9d43"
  instance_type = var.instance_type
  tags = {
    Name    = "${local.shop_name}-app"
    Purpose = "acme-shop web tier"
  }
}