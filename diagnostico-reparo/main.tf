# Serviço de Diagnóstico e Reparo: andamento do trabalho na oficina (NoSQL).
locals {
  name       = "${var.project_name}-${var.environment}-diagnostico-reparo"
  table_name = "${var.project_name}-${var.environment}-execucoes"
  fila_index = "etapa-entradaFilaEm-index"
}

# Um item por OS (chave numeroOs = correlationId da Saga). O índice por etapa
# lista a fila do técnico em ordem de chegada.
resource "aws_dynamodb_table" "execucoes" {
  #checkov:skip=CKV_AWS_119:A LabRole acadêmica não administra chave KMS de cliente; usa a chave gerenciada pela AWS.
  name                        = local.table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "numeroOs"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "numeroOs"
    type = "S"
  }

  attribute {
    name = "etapa"
    type = "S"
  }

  attribute {
    name = "entradaFilaEm"
    type = "S"
  }

  global_secondary_index {
    name            = local.fila_index
    hash_key        = "etapa"
    range_key       = "entradaFilaEm"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = local.table_name
  }
}
