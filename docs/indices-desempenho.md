# Índices e desempenho

## Índices prioritários

| Consulta | Índice | Situação |
|---|---|---|
| Login por CPF ativo | `idx_clientes_cpf_ativo` | Implementado |
| Documento normalizado único | `ux_clientes_documento_normalizado` | Implementado |
| Etapa aberta da OS | `ux_historico_os_status_aberto` | Implementado |
| Histórico ordenado da OS | `idx_historico_os_entrada` | Implementado |
| Histórico por status e período | `idx_historico_status_periodo` | Implementado |
| Item de orçamento por serviço/SKU | `idx_itens_orc_servico_sku` | Implementado na V4 |
| Financeiro por nota e fornecedor | `idx_cc_nota_fornecedor` | Implementado na V4 |
| Financeiro por tipo e data | `idx_cc_tipo_data` | Implementado na V4 |

A V4 remove o índice simples redundante `idx_cc_tipo`, substituído pelo índice composto que também atende a ordenação por data.

## Decisões de desempenho

- Índices são guiados pelas consultas reais dos repositórios de persistência.
- Índices redundantes são evitados para não aumentar custo de escrita.
- Consultas de baixo volume podem permanecer com varredura sequencial.
- Novos índices devem ser confirmados com volume representativo e `EXPLAIN ANALYZE`.

## Evidência recomendada

Antes da entrega final, executar `EXPLAIN (ANALYZE, BUFFERS)` nas consultas críticas e registrar plano, tempo e uso do índice. Essa evidência complementa a revisão estática sem alterar o modelo lógico.
