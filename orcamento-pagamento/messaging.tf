# Comandos da Saga enviados pelo OS Service ao Orçamento e Pagamento.
module "fila" {
  source = "../modules/sqs-com-dlq"

  name = "${local.name}-comandos"
}
