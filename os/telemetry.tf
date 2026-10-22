data "archive_file" "rds_newrelic_telemetry" {
  type        = "zip"
  source_file = "${path.module}/lambda/rds_newrelic_telemetry.py"
  output_path = "${path.module}/rds-newrelic-telemetry.zip"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  lab_role_arn          = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  postgres_log_group    = "/aws/rds/instance/${local.db_identifier}/postgresql"
  telemetry_name        = "${local.name}-rds-newrelic-telemetry"
  telemetry_environment = var.rds_newrelic_telemetry_enabled ? { enabled = true } : {}
}

resource "aws_cloudwatch_log_group" "rds_telemetry" {
  for_each = local.telemetry_environment

  name              = "/aws/lambda/${local.telemetry_name}"
  retention_in_days = var.cloudwatch_logs_retention_days
}

resource "aws_sqs_queue" "rds_telemetry_dlq" {
  for_each = local.telemetry_environment

  name                      = "${local.telemetry_name}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_lambda_function" "rds_telemetry" {
  #checkov:skip=CKV_AWS_173:A LabRole acadêmica não administra uma chave KMS de cliente.
  #checkov:skip=CKV_AWS_272:O pacote interno é validado por hash e o Learner Lab não fornece perfil de assinatura.
  #checkov:skip=CKV_AWS_117:A função acessa APIs públicas AWS e New Relic; uma VPC exigiria NAT pago.
  for_each = local.telemetry_environment

  function_name                  = local.telemetry_name
  description                    = "Publica métricas agregadas e contagens sanitizadas do RDS no New Relic"
  role                           = local.lab_role_arn
  runtime                        = "python3.12"
  architectures                  = ["arm64"]
  handler                        = "rds_newrelic_telemetry.handler"
  timeout                        = 60
  memory_size                    = 256
  reserved_concurrent_executions = 1

  filename         = data.archive_file.rds_newrelic_telemetry.output_path
  source_code_hash = data.archive_file.rds_newrelic_telemetry.output_base64sha256

  environment {
    variables = {
      ENVIRONMENT             = var.environment
      NEW_RELIC_ACCOUNT_ID    = tostring(var.newrelic_account_id)
      NEW_RELIC_LICENSE_KEY   = var.newrelic_license_key
      NEW_RELIC_REGION        = var.newrelic_region
      RDS_INSTANCE_IDENTIFIER = local.db_identifier
      RDS_LOG_GROUP_NAME      = local.postgres_log_group
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.rds_telemetry_dlq[each.key].arn
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_cloudwatch_log_group.database,
    aws_cloudwatch_log_group.rds_telemetry,
    aws_db_instance.main,
  ]

  lifecycle {
    precondition {
      condition     = var.newrelic_account_id > 0 && var.newrelic_license_key != ""
      error_message = "A telemetria RDS exige newrelic_account_id e newrelic_license_key."
    }

    precondition {
      condition     = contains(var.enabled_cloudwatch_logs_exports, "postgresql")
      error_message = "A telemetria RDS exige o log postgresql em enabled_cloudwatch_logs_exports."
    }
  }
}

resource "aws_cloudwatch_event_rule" "rds_telemetry" {
  for_each = local.telemetry_environment

  name                = local.telemetry_name
  description         = "Coleta telemetria agregada do RDS a cada cinco minutos"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "rds_telemetry" {
  for_each = local.telemetry_environment

  rule      = aws_cloudwatch_event_rule.rds_telemetry[each.key].name
  target_id = "RdsNewRelicTelemetry"
  arn       = aws_lambda_function.rds_telemetry[each.key].arn
}

resource "aws_lambda_permission" "rds_telemetry" {
  for_each = local.telemetry_environment

  statement_id  = "AllowEventBridgeRdsTelemetry"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_telemetry[each.key].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_telemetry[each.key].arn
}
