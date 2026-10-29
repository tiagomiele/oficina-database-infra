# Modelo relacional

## Fonte do schema

| Migration | Ajuste |
|---|---|
| V1 | Schema inicial da oficina |
| V2 | Início e fim da execução da OS |
| V3 | CPF normalizado e histórico de status |
| V4 | Índices das consultas prioritárias |

As migrations vivem no repositório Backend. Este documento apresenta o modelo resultante.

## Entidades

| Entidade | Identificador | Papel |
|---|---|---|
| `users` | UUID | Usuários administrativos e perfis internos |
| `clientes` | `id_cliente` | Clientes CPF/CNPJ e situação cadastral |
| `veiculos` | placa + cliente | Veículos pertencentes aos clientes |
| `servicos` | `id_servico` | Catálogo de serviços |
| `pecas` | `id_sku` | Catálogo de peças |
| `estoque_pecas` | `id_sku` | Saldo atual de cada peça |
| `movimentacao_estoque_pecas` | `id` | Histórico de entrada, saída e reserva |
| `notas_fiscais_fornecedor` | nota + série + CNPJ + data | Compras de fornecedor |
| `itens_nota_fiscal_fornecedor` | nota + item | Itens das compras |
| `numero_os_sequencia` | mês + ano | Numeração mensal e concorrente das OSs |
| `ordens_servico` | número da OS | Agregado principal da oficina |
| `orcamentos_itens_ordem_servico` | OS + orçamento + item | Serviços e peças do orçamento |
| `historico_status_ordem_servico` | `id` | Entrada e saída em cada status da OS |
| `conta_corrente_oficina` | `id` | Lançamentos financeiros e correlações |

## Relacionamentos

| Origem | Destino | Cardinalidade | Controle |
|---|---|---|---|
| clientes | veículos | 1:N | FK |
| clientes | ordens de serviço | 1:N | FK |
| veículos | ordens de serviço | 1:N | FK composta |
| peças | estoque | 1:0..1 | FK na PK |
| peças | movimentações | 1:N | FK |
| notas fiscais | itens da nota | 1:N | FK composta com cascade |
| peças | itens da nota | 1:N | FK |
| ordens de serviço | itens do orçamento | 1:N | FK |
| ordens de serviço | histórico de status | 1:N | FK com cascade |
| nota fiscal | conta corrente | 1:N lógico | Correlação por campos da nota |
| ordem de serviço | movimentações e financeiro | 1:N lógico | Referência de negócio sem FK deliberada |

## Regras de consistência

- Documento do cliente é único; a coluna gerada `documento_normalizado` remove máscara.
- CPF ativo possui índice parcial para autenticação.
- Quantidades e valores usam constraints para impedir estados inválidos.
- Só pode existir uma etapa aberta por OS, garantida por índice único parcial.
- O saldo de estoque é separado do histórico de movimentações.
- PKs compostas preservam identidades naturais relevantes.

## Diagrama

- [Visualização organizada por domínio](assets/modelo-relacional-database.png)
- [Fonte Mermaid editável](diagrams/er-model.mmd)
- [Decisão de consistência](adr/0001-consistencia-modelo.md)
- [Revisão de desempenho](indices-desempenho.md)
