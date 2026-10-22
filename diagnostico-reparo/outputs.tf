output "table_name" {
  description = "Tabela DynamoDB de execuções."
  value       = aws_dynamodb_table.execucoes.name
}

output "table_arn" {
  description = "ARN da tabela DynamoDB."
  value       = aws_dynamodb_table.execucoes.arn
}

output "fila_index_name" {
  description = "Índice que lista a fila do técnico por etapa e ordem de chegada."
  value       = local.fila_index
}

output "queue_name" {
  description = "Fila SQS de entrada do Diagnóstico e Reparo."
  value       = module.fila.queue_name
}

output "queue_url" {
  description = "URL da fila SQS de entrada do Diagnóstico e Reparo."
  value       = module.fila.queue_url
}

output "queue_arn" {
  description = "ARN da fila SQS de entrada do Diagnóstico e Reparo."
  value       = module.fila.queue_arn
}

output "dlq_name" {
  description = "DLQ da fila de entrada do Diagnóstico e Reparo."
  value       = module.fila.dlq_name
}

output "dlq_url" {
  description = "URL da DLQ do Diagnóstico e Reparo."
  value       = module.fila.dlq_url
}
