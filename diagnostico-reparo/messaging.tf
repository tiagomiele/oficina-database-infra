# Comandos da Saga enviados pelo OS Service ao Diagnóstico e Reparo.
module "fila" {
  source = "../modules/sqs-com-dlq"

  name = "${local.name}-comandos"
}
