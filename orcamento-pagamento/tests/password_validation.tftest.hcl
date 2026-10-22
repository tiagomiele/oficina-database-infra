mock_provider "aws" {}

variables {
  vpc_id                     = "vpc-0123456789abcdef0"
  private_subnet_ids         = ["subnet-0123456789abcdef0", "subnet-abcdef01234567890"]
  allowed_security_group_ids = ["sg-0123456789abcdef0"]
  db_password                = "SafeRdsPassword!123456789"
}

run "accepts_aws_compatible_password" {
  command = plan
}

run "rejects_aws_forbidden_password_character" {
  command = plan

  variables {
    db_password = "Invalid@Password123456"
  }

  expect_failures = [var.db_password]
}
