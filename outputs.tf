output "database_identifier" {
  description = "Identificador da instância RDS."
  value       = aws_db_instance.main.identifier
}

output "database_endpoint" {
  description = "Hostname do RDS sem credenciais."
  value       = aws_db_instance.main.address
}

output "database_port" {
  description = "Porta do PostgreSQL."
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Nome do banco inicial."
  value       = var.db_name
}

output "database_security_group_id" {
  description = "Security group do RDS para integrações futuras."
  value       = aws_security_group.database.id
}

output "database_log_groups" {
  description = "Log groups do CloudWatch usados na validação de observabilidade."
  value       = [for log in var.enabled_cloudwatch_logs_exports : "/aws/rds/instance/${aws_db_instance.main.identifier}/${log}"]
}

output "performance_insights_enabled" {
  description = "Indica se o Performance Insights foi habilitado no ambiente."
  value       = aws_db_instance.main.performance_insights_enabled
}

output "jdbc_url" {
  description = "URL JDBC sem usuário ou senha."
  value       = "jdbc:postgresql://${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"
}

output "rds_newrelic_telemetry_function_name" {
  description = "Lambda agendada que publica telemetria agregada do RDS no New Relic."
  value       = try(aws_lambda_function.rds_telemetry["enabled"].function_name, null)
}
