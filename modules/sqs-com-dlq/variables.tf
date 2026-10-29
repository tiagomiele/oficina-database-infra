variable "name" {
  description = "Nome da fila principal; a DLQ recebe o sufixo -dlq."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,76}$", var.name))
    error_message = "name deve ter até 76 caracteres alfanuméricos, hífen ou sublinhado."
  }
}

variable "visibility_timeout_seconds" {
  description = "Tempo em que a mensagem fica invisível enquanto o consumidor processa."
  type        = number
  default     = 60
}

variable "message_retention_seconds" {
  description = "Retenção das mensagens na fila principal."
  type        = number
  default     = 345600
}

variable "max_receive_count" {
  description = "Tentativas de processamento antes de mover a mensagem para a DLQ."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count deve estar entre 1 e 1000."
  }
}
