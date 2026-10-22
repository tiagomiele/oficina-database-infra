# ADR 0001 — Consistência do modelo relacional

- **Status:** aceita

## Decisão

Manter o domínio em terceira forma normal, combinando chaves surrogate com chaves naturais compostas quando a identidade pertence ao negócio.

## Controles adotados

1. FKs garantem integridade entre clientes, veículos, OSs, catálogos e itens.
2. Chaves compostas impedem duplicidade em veículos, notas, itens e numeração mensal.
3. `CHECK constraints` restringem quantidades, tipos e estados válidos.
4. CPF/CNPJ é preservado e também normalizado em coluna gerada `STORED`.
5. Índice único parcial impede duas etapas abertas para a mesma OS.
6. Saldo de estoque e histórico de movimentações permanecem separados.
7. Correlações polimórficas ou opcionais permanecem sem FK apenas quando uma FK rígida não representa corretamente o domínio.

## Consequências

O banco protege invariantes essenciais sem depender apenas da aplicação. Relações lógicas sem FK exigem testes e validações no Backend.
