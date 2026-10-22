<#
.SYNOPSIS
    Confirma, de dentro de um pod no EKS, que a LabRole dos nós acessa as filas SQS
    e a tabela DynamoDB da Fase 4. Não altera a infraestrutura: só envia, lê e apaga
    uma mensagem de teste em cada fila e um item de teste na tabela.

.EXAMPLE
    .\scripts\test-labrole-access.ps1 -Environment homolog
#>
[CmdletBinding()]
param(
    [ValidateSet('homolog', 'production')]
    [string]$Environment = 'homolog',
    [string]$Namespace = 'default',
    [string]$AwsRegion = 'us-west-2',
    [string]$ProjectName = 'oficina',
    [string]$Image = 'public.ecr.aws/aws-cli/aws-cli:2.17.0'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($command in @('aws', 'kubectl')) {
    if ($null -eq (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Comando obrigatório não encontrado: $command"
    }
}

$prefix = "$ProjectName-$Environment"
$queues = @("$prefix-os-eventos", "$prefix-orcamento-pagamento-comandos", "$prefix-diagnostico-reparo-comandos")
$table = "$prefix-execucoes"

& aws eks update-kubeconfig --region $AwsRegion --name "oficina-$Environment" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Não foi possível configurar o kubectl para o cluster oficina-$Environment."
}

# O pod não recebe credenciais: a AWS CLI usa o perfil da instância (LabRole do nó).
$checks = @(
    'set -u',
    'fail=0',
    'check() { if "$@" >/dev/null 2>&1; then echo "OK    $NAME"; else echo "FALHA $NAME"; fail=1; fi; }'
)
foreach ($queue in $queues) {
    $checks += "URL=`$(aws sqs get-queue-url --queue-name $queue --query QueueUrl --output text 2>/dev/null) || URL=''"
    $checks += "NAME='SQS send $queue'; check aws sqs send-message --queue-url `"`$URL`" --message-body labrole-check"
    $checks += "NAME='SQS receive/delete $queue'; check sh -c 'H=`$(aws sqs receive-message --queue-url `"`$0`" --wait-time-seconds 5 --query Messages[0].ReceiptHandle --output text) && [ `"`$H`" != None ] && aws sqs delete-message --queue-url `"`$0`" --receipt-handle `"`$H`"' `"`$URL`""
}
$item = '{"numeroOs":{"S":"LABROLE-CHECK"},"etapa":{"S":"NA_FILA_DIAGNOSTICO"},"entradaFilaEm":{"S":"1970-01-01T00:00:00Z"}}'
$key = '{"numeroOs":{"S":"LABROLE-CHECK"}}'
$checks += "NAME='DynamoDB put $table'; check aws dynamodb put-item --table-name $table --item '$item'"
$checks += "NAME='DynamoDB get $table'; check aws dynamodb get-item --table-name $table --key '$key'"
$checks += "NAME='DynamoDB query índice $table'; check aws dynamodb query --table-name $table --index-name etapa-entradaFilaEm-index --key-condition-expression 'etapa = :e' --expression-attribute-values '{`":e`":{`"S`":`"NA_FILA_DIAGNOSTICO`"}}'"
$checks += "NAME='DynamoDB delete $table'; check aws dynamodb delete-item --table-name $table --key '$key'"
$checks += 'exit $fail'
$script = $checks -join "`n"

$podName = "labrole-check-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
Write-Host "Executando o pod $podName no namespace $Namespace..."
& kubectl run $podName --namespace $Namespace --image $Image --restart=Never --rm -i --quiet `
    --env "AWS_REGION=$AwsRegion" --env "AWS_DEFAULT_REGION=$AwsRegion" `
    --command -- sh -c $script
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host 'LabRole validada: o pod acessa as 3 filas SQS e a tabela DynamoDB.'
}
else {
    Write-Warning 'Algum acesso falhou. Se TODOS falharam, verifique o hop limit do IMDS dos nós (precisa ser 2) ou acione o plano B combinado.'
    exit $exitCode
}
