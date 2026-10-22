> **Tech Challenge Fase 4 — `oficina-database-infra`**
>
> Bancos e filas isolados por serviço (RDS, DynamoDB e SQS).
>
> Base importada de [`fiap-tech-challenge-fase3-oficina-database-infra`](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-database-infra) (commit `8952100`), sem alterações funcionais. A evolução para a Fase 4 é feita por PRs nas próximas fases; o conteúdo abaixo ainda descreve a Fase 3.

# Oficina Fase 3 — Database

Infraestrutura como código responsável pelo PostgreSQL privado da Oficina no Amazon RDS, incluindo rede, segurança, disponibilidade, backup, logs e telemetria.

## Visão de negócio

O Database preserva a memória operacional da oficina. Nele ficam clientes e sua situação cadastral, veículos, catálogos, estoque, fornecedores, Ordens de Serviço, históricos de status e lançamentos financeiros.

Essa base permite autenticar somente clientes ativos, manter a rastreabilidade do atendimento, impedir inconsistências de estoque e produzir relatórios e indicadores. Por isso, privacidade, integridade, recuperação e desempenho são requisitos de negócio, não apenas decisões técnicas.

## Responsabilidades

- provisionar Amazon RDS PostgreSQL privado e criptografado;
- restringir conectividade aos componentes autorizados;
- configurar armazenamento, backup, manutenção e proteção por ambiente;
- exportar logs e telemetria agregada sem expor dados pessoais;
- fornecer outputs de conexão sem usuário ou senha;
- manter states HCP independentes para homologação e produção;
- documentar o modelo relacional, relacionamentos, constraints e índices.

As migrations Flyway V1–V4 permanecem no Backend como fonte executável do schema. Este projeto entrega o serviço gerenciado e não duplica a definição funcional das tabelas.

## Arquitetura do componente

![Arquitetura do Database com RDS PostgreSQL privado, Terraform e observabilidade](docs/assets/arquitetura-database.png)

```text
Backend no EKS ─────────────┐
                            ├─ Security Group autorizado
Auth Lambda na VPC ─────────┘
                                      ↓
                         RDS PostgreSQL privado
                         ├─ SSL e criptografia
                         ├─ backup e snapshots
                         └─ logs PostgreSQL
                                      ↓
                         CloudWatch / telemetria
                                      ↓
                                New Relic
```
O RDS não possui endpoint público. A conectividade é permitida somente aos componentes autorizados dentro da VPC.

## Modelo arquitetural e práticas

O projeto utiliza **Infrastructure as Code declarativa**. Terraform descreve RDS, subnet group, security group, parâmetros, backup, logs, telemetria e outputs. O plan permite revisar impactos antes do apply, e o state remoto separa homologação de produção.

O modelo de dados é relacional e normalizado. O Backend controla transações e migrations; o PostgreSQL reforça integridade com:
- chaves primárias e estrangeiras;
- chaves compostas;
- constraints de domínio;
- índices alinhados às consultas;
- histórico de status da Ordem de Serviço;
- controle de consistência de estoque e lançamentos.


- [Modelo relacional](docs/modelo-relacional.md)
- [Diagrama visual](docs/assets/modelo-relacional-database.png)
- [ADR de consistência](docs/adr/0001-consistencia-modelo.md)
- [Índices e desempenho](docs/indices-desempenho.md)

## Stack e ferramentas

| Área | Tecnologias |
|---|---|
| Banco | Amazon RDS PostgreSQL 16 |
| Infraestrutura | Terraform, HCP Terraform, VPC, sub-redes privadas e Security Groups |
| Segurança | SSL obrigatório, criptografia, banco privado e Secrets externos |
| Disponibilidade | Multi-AZ por ambiente, backups e snapshot final configurável |
| Logs | PostgreSQL logs e Amazon CloudWatch Logs |
| Telemetria | AWS Lambda Python, EventBridge e New Relic Event API |
| Modelo funcional | SQL, Flyway, constraints e índices |
| Qualidade | Terraform Validate, TFLint, testes Terraform e testes Python |
| Segurança de código | Checkov, Trivy e Gitleaks |
| Automação | GitHub Actions, GitHub Environments e sincronização de outputs |

## Estrutura de pastas

```text
.
├── .github/workflows/
│   ├── ci.yml                    # validações de Terraform, testes e segurança
│   ├── terraform-plan.yml        # plan de homologação e produção
│   └── terraform-apply.yml       # apply por ambiente
├── docs/
│   ├── modelo-relacional.md
│   ├── indices-desempenho.md
│   ├── adr/                      # decisões do modelo de dados
│   ├── diagrams/                 # fontes editáveis do diagrama ER
│   └── assets/                   # diagramas renderizados
├── environments/                 # exemplos de variáveis por ambiente
├── lambda/                       # coletor sanitizado de telemetria do RDS
├── scripts/                      # validação documental e sincronização
├── tests/                        # testes Terraform e Python
├── main.tf                       # RDS, rede de acesso, parâmetros e logs
├── telemetry.tf                  # Lambda, EventBridge e New Relic
├── providers.tf
├── variables.tf
├── outputs.tf
└── versions.tf
```

## Pré-requisitos

- Git;
- Terraform compatível com `versions.tf`;
- Python 3 para testes e scripts;
- TFLint para validação estática;
- credenciais AWS somente para plans e deploys remotos;
- organização e workspaces HCP Terraform configurados.

## Validar localmente

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
tflint --recursive
python3 scripts/validate_docs.py
python3 -m unittest discover -s tests -p 'test_*.py'
```
Os comandos locais validam a configuração e não criam recursos na AWS.

## Configuração por ambiente

- [Homologação](environments/homolog.tfvars.example)
- [Produção](environments/production.tfvars.example)

Principais grupos de variáveis:

| Grupo | Exemplos de finalidade |
|---|---|
| Identificação | projeto, ambiente e região AWS |
| Rede | VPC, sub-redes privadas e Security Groups permitidos |
| Banco | versão, classe, armazenamento, nome e usuário |
| Segurança | senha sensível, SSL e acesso privado |
| Disponibilidade | Multi-AZ, backup, deletion protection e snapshot final |
| Logs | exports PostgreSQL, retenção e consultas lentas |
| New Relic | conta, região, ingest key e habilitação da telemetria |

A senha do banco e a chave New Relic devem ser variáveis sensíveis no HCP Terraform. Não crie arquivos `.tfvars` com credenciais reais no repositório.

## Outputs principais

O projeto publica somente dados necessários à integração, como:

- identificador e endpoint do RDS;
- porta e nome lógico do banco;
- Security Group do banco;
- informações de rede necessárias aos projetos consumidores;
- estado da telemetria.

Usuário e senha não são publicados como outputs.

## CI/CD e implantação

| Etapa | Comportamento |
|---|---|
| Pull Request | executa CI e Terraform Plan, sem criar ou alterar recursos |
| Merge em `homolog` | aplica a infraestrutura de homologação |
| Sincronização | envia endpoint e parâmetros não sensíveis para Auth e Backend |
| Promoção para `main` | aplica produção pelo GitHub Environment protegido |

Fluxo de promoção:

```text
feature → Pull Request → homolog → Pull Request → main
```

Na implantação completa da Oficina, o Database deve ser aplicado depois do Kubernetes, pois utiliza VPC, sub-redes e Security Groups produzidos pelo projeto de plataforma.

## Operação e segurança

- o RDS permanece privado;
- acessos administrativos devem ocorrer por túnel seguro ou recurso autorizado dentro da VPC;
- conexões externas diretas não devem ser liberadas para `0.0.0.0/0`;
- logs devem evitar parâmetros, documentos e dados pessoais;
- produção deve manter proteção contra exclusão e política de snapshot coerente;
- alterações devem ser revisadas pelo Terraform Plan antes do apply.

## Documentação e evidências

- [Documentação central da Fase 3](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-backend/tree/feature/validacao-deploy-aplicacao)
- [Requisitos obrigatórios e evidências](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-backend/blob/feature/validacao-deploy-aplicacao/README-requisitos-obrigatorios-fase-3.md)

## Projetos relacionados

- [Backend](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-backend)
- [Auth Serverless](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-auth-serverless)
- [Kubernetes Infra](https://github.com/tiagomiele/fiap-tech-challenge-fase3-oficina-kubernetes-infra)

## Licença

Consulte o arquivo [LICENSE](LICENSE).

