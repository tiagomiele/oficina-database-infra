mock_provider "aws" {}

run "tabela_com_indice_da_fila" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.execucoes.hash_key == "numeroOs"
    error_message = "A chave da tabela deve ser numeroOs."
  }

  assert {
    condition     = one(aws_dynamodb_table.execucoes.global_secondary_index).hash_key == "etapa"
    error_message = "O índice da fila deve ser por etapa."
  }

  assert {
    condition     = aws_dynamodb_table.execucoes.billing_mode == "PAY_PER_REQUEST"
    error_message = "A tabela deve ser sob demanda para custo baixo no Learner Lab."
  }
}

run "rejeita_ambiente_invalido" {
  command = plan

  variables {
    environment = "dev"
  }

  expect_failures = [var.environment]
}
