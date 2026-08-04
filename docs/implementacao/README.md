# Tickets de implementação

Este diretório é o tracker da **implementação**. Ele existe pela mesma razão que
[`docs/mapa/`](../mapa/): o repositório usa tracker markdown local, versionado em `docs/` porque é
documentação de primeira classe, não rascunho descartável.

A diferença entre os dois:

| | |
|---|---|
| [`docs/mapa/`](../mapa/) | as **decisões** — 49 tickets fechados, com os argumentos recusados |
| [`docs/especificacao.md`](../especificacao.md) | a **especificação**, sintetizada deles |
| `docs/implementacao/` | o **trabalho**, fatiado em tracer bullets |

Cada ticket é uma fatia vertical: um caminho estreito mas **completo** por todas as camadas,
demonstrável sozinho. Não são fatias horizontais de uma camada — não existe ticket "o schema" ou "a
API", existem tickets que fazem um comportamento funcionar de ponta a ponta.

## Formato

```markdown
# NN — Título

**O que construir:** o comportamento que este ticket faz funcionar, pela perspectiva de quem usa.
**Bloqueado por:** os números que precisam terminar antes, ou "nada — pode começar imediatamente".
**Status:** ready-for-agent

**Critérios de aceitação**
- [ ] ...
```

Os critérios referenciam os **cenários obrigatórios** da especificação pelo identificador
(`CO-*`). Esses identificadores são o gate real do CI: cada um é um teste marcado, e o pipeline
afirma que todos **rodaram e passaram** — nunca que existem.

## Como trabalhar

Trabalhe a **fronteira**: qualquer ticket cujos bloqueadores estejam todos concluídos. A numeração
está em ordem de dependência, então os bloqueadores de um ticket sempre têm número menor que ele —
mas a ordem **não** é uma fila. Vários tickets ficam livres ao mesmo tempo.

Três frentes ficam livres cedo e correm em paralelo: os quatro Produtos restantes (10–13, todos
bloqueados só pelo 07 e independentes entre si), a API a partir de identidade (14), e a plataforma
(30, que só espera o 14).

## Os tickets

**Prefactor** — "deixe a mudança fácil, depois faça a mudança fácil"

| # | Ticket | Bloqueado por |
|---|---|---|
| 01 | [Reconciliar a SPI e os dez beans com os Relatórios decididos](issues/01-reconciliar-spi-e-beans.md) | — |
| 02 | [Schema de controle: migrações e os sete usuários](issues/02-schema-de-controle.md) | — |
| 03 | [Contrato de erro RFC 9457, catálogo e Correlation ID](issues/03-contrato-de-erro.md) | — |

**Coleta**

| # | Ticket | Bloqueado por |
|---|---|---|
| 04 | [Publicação do inventário](issues/04-publicacao-do-inventario.md) | 01, 02 |
| 05 | [Coleta ponta a ponta de um Relatório sintético](issues/05-coleta-ponta-a-ponta-sintetico.md) | 01, 02 |
| 06 | [Os desfechos não-felizes da Coleta](issues/06-desfechos-nao-felizes-da-coleta.md) | 05 |
| 07 | [Leitura em cursor e o Relatório analítico](issues/07-cursor-e-relatorio-analitico.md) | 05 |
| 08 | [`hash_definicao`, `imagem_origem` e divergência de inventário](issues/08-hash-definicao-e-imagem-origem.md) | 04, 05 |
| 09 | [Telemetria e métricas da Coleta](issues/09-telemetria-da-coleta.md) | 05 |
| 10 | [Produto Cliente](issues/10-produto-cliente.md) | 07 |
| 11 | [Produto Conta Corrente](issues/11-produto-contacorrente.md) | 07 |
| 12 | [Produto Consórcio](issues/12-produto-consorcio.md) | 07 |
| 13 | [Produto Empréstimo](issues/13-produto-emprestimo.md) | 07 |

**API**

| # | Ticket | Bloqueado por |
|---|---|---|
| 14 | [Identidade: realm semente e resource server](issues/14-identidade-realm-e-resource-server.md) | 03 |
| 15 | [Listagem de Execuções disponíveis](issues/15-listagem-de-execucoes-disponiveis.md) | 02, 14 |
| 16 | [Exportação CSV](issues/16-exportacao-csv.md) | 05, 15 |
| 17 | [Exportação PDF e DOCX, com semáforo e defesas](issues/17-exportacao-pdf-docx-e-semaforo.md) | 16 |
| 18 | [Exportação XLSX com a linha de base do exporter](issues/18-exportacao-xlsx.md) | 17 |
| 19 | [Retenção: marcação de expirado e `410`](issues/19-retencao-expirado-e-410.md) | 16 |
| 20 | [Cadastro de Produto e Relatório](issues/20-cadastro-de-produto-e-relatorio.md) | 04, 15 |
| 21 | [Mediação do Keycloak: Roles, Grupos e `PENDENTES`](issues/21-mediacao-do-keycloak.md) | 03, 14 |
| 22 | [Snapshot do agendamento para a fábrica de DAGs](issues/22-snapshot-do-agendamento.md) | 20 |

**Orquestração**

| # | Ticket | Bloqueado por |
|---|---|---|
| 23 | [DAG de Coleta de um Relatório](issues/23-dag-de-coleta.md) | 05, 20 |
| 24 | [Fábrica de DAGs](issues/24-fabrica-de-dags.md) | 22, 23 |
| 25 | [DAG de varredura de órfãs](issues/25-varredura-de-orfas.md) | 23 |
| 26 | [`refazer` e `reprocessar`](issues/26-refazer-e-reprocessar.md) | 20, 24 |

**Frontend**

| # | Ticket | Bloqueado por |
|---|---|---|
| 27 | [Angular: shell, OIDC e a tela do RELATOR](issues/27-angular-shell-oidc-e-tela-do-relator.md) | 15, 16 |
| 28 | [Angular: telas do GERENTE](issues/28-angular-telas-do-gerente.md) | 21, 27 |
| 29 | [Angular: telas do ADMINISTRADOR](issues/29-angular-telas-do-administrador.md) | 20, 26, 27 |

**Plataforma**

| # | Ticket | Bloqueado por |
|---|---|---|
| 30 | [Ingress e e-mail: Traefik e Mailpit](issues/30-ingress-e-email.md) | 14 |
| 31 | [Observabilidade e painel-resumo](issues/31-observabilidade-e-painel-resumo.md) | 09, 17 |
| 32 | [CI: workflows e os gates](issues/32-ci-workflows-e-gates.md) | 05, 15 |
| 33 | [`deploy.sh`, runbook e verificações](issues/33-deploy-runbook-e-verificacoes.md) | 24, 30, 32 |

## O que já está pronto

As quatro fases iniciais foram entregues e aprovadas antes destes tickets, e o esqueleto que elas
deixaram é o ponto de partida:

- protótipo HTML/CSS/JS descartável e OpenAPI descartável, em [`docs/mapa/prototipos/`](../mapa/prototipos/);
- onze módulos Maven compilando, com o contrato de saída do processo já correto;
- os endpoints de liveness e readiness respondendo, com o indicador de banco **amortecido** —
  incluindo os cenários de amortecimento, de liveness sem banco e de actuator não exposto, que já
  passam e só precisam entrar na lista executável do ticket 32;
- os cinco schemas transacionais, as dez definições de JRXML e as sementes.

O ticket 01 existe porque esse esqueleto foi escrito **antes** das decisões sobre a definição do
relatório, e diverge delas em três pontos.
