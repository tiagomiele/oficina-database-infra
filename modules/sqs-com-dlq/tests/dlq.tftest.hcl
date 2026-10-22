mock_provider "aws" {}

variables {
  name = "oficina-homolog-os-eventos"
}

run "fila_com_dlq" {
  command = apply

  assert {
    condition     = aws_sqs_queue.dlq.name == "oficina-homolog-os-eventos-dlq"
    error_message = "A DLQ deve usar o nome da fila com o sufixo -dlq."
  }

  assert {
    condition     = jsondecode(aws_sqs_queue.main.redrive_policy).maxReceiveCount == 5
    error_message = "A fila deve mover a mensagem para a DLQ após 5 tentativas."
  }

  assert {
    condition     = aws_sqs_queue.main.sqs_managed_sse_enabled && aws_sqs_queue.dlq.sqs_managed_sse_enabled
    error_message = "As filas devem ser criptografadas."
  }
}

run "rejeita_nome_invalido" {
  command = plan

  variables {
    name = "fila com espaço"
  }

  expect_failures = [var.name]
}
