output "queue_name" {
  description = "Nome da fila principal."
  value       = aws_sqs_queue.main.name
}

output "queue_url" {
  description = "URL da fila principal."
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "ARN da fila principal."
  value       = aws_sqs_queue.main.arn
}

output "dlq_name" {
  description = "Nome da DLQ."
  value       = aws_sqs_queue.dlq.name
}

output "dlq_url" {
  description = "URL da DLQ."
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "ARN da DLQ."
  value       = aws_sqs_queue.dlq.arn
}
