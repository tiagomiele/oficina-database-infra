variable "aws_region" {
  description = "Região AWS."
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Prefixo dos recursos."
  type        = string
  default     = "oficina"
}

variable "environment" {
  description = "Ambiente: homolog ou production."
  type        = string
  default     = "homolog"

  validation {
    condition     = contains(["homolog", "production"], var.environment)
    error_message = "environment deve ser homolog ou production."
  }
}

variable "deletion_protection" {
  description = "Impede a exclusão acidental da tabela DynamoDB."
  type        = bool
  default     = false
}

variable "point_in_time_recovery" {
  description = "Backup contínuo da tabela (PITR)."
  type        = bool
  default     = true
}
