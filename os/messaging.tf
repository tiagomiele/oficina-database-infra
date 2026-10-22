# Eventos dos outros serviços para o orquestrador da Saga (OS Service).
module "fila" {
  source = "../modules/sqs-com-dlq"

  name = "${local.name}-eventos"
}
