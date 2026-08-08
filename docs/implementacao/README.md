# Tickets de implementação

O trabalho do MVP fatiado em **tracer bullets**, derivado de [`../especificacao.md`](../especificacao.md).

Tracker markdown local, versionado em `docs/` porque é documentação de primeira classe, não
rascunho descartável.

| Documento | Papel |
|---|---|
| [`../prd.md`](../prd.md) | o **quê** e o **porquê** — `RN-NN`, `RF-NN`, `RNF-NN` |
| [`../arquitetura-inicial.md`](../arquitetura-inicial.md) | o **como** — `RA-NN` |
| [`../especificacao.md`](../especificacao.md) | a **especificação** do MVP: histórias, decisões e as três costuras |
| `docs/implementacao/` | o **trabalho**, fatiado |

Cada ticket é uma fatia **vertical**: um caminho estreito mas completo por todas as camadas,
demonstrável sozinho. Não existe ticket "o schema" ou "a API" — existem tickets que fazem um
comportamento funcionar de ponta a ponta.

## Formato

```markdown
# NN — Título

**O que construir:** o comportamento que este ticket faz funcionar, pela perspectiva de quem usa.
**Bloqueado por:** os números que precisam terminar antes, ou "nada — pode começar imediatamente".
**Status:** ready-for-agent

**Critérios de aceitação**
- [ ] ...
```

Os critérios referenciam o PRD e a arquitetura pelo identificador. Um `RF-NN` ou `RA-NN` no critério
é onde o teste vai buscar o que afirmar.

## Como trabalhar

Trabalhe a **fronteira**: qualquer ticket cujos bloqueadores estejam todos concluídos. A numeração
está em ordem de dependência — os bloqueadores de um ticket sempre têm número menor —, mas **não é
uma fila**. Vários tickets ficam livres ao mesmo tempo.

Três frentes ficam livres cedo e correm em paralelo: os documentos de design (03 e 04, ambos sem
bloqueador), a Coleta a partir de 05, e a plataforma a partir de 06.

Quatro tickets ficam livres de uma vez quando 16 fechar: os produtos 23 a 26 são independentes
entre si.

## Onde estão os três cenários canônicos

Não existe teste algum no repositório de onde copiar padrão (especificação §5.4). O **primeiro**
cenário escrito em cada costura vira o molde de todas as sessões seguintes, e por isso os três
carregam peso além do seu tamanho:

| Costura | Ticket | Entra por |
|---|---|---|
| **S1** | [06](issues/06-bootstrap-da-api-erro-e-correlation-id.md) | HTTP na API REST |
| **S2** | [09](issues/09-coleta-ponta-a-ponta-poupanca.md) | invocação do job de coleta do produto |
| **S3** | [12](issues/12-dag-reserva-pool-e-callback-de-falha.md) | DAG, com as tasks de produto em dublê |

Os três precisam ser citados nominalmente no `ARCHITECTURE.md` como implementação de referência.

## Os quatro testes obrigatórios por natureza de risco

São os que ninguém escreve espontaneamente (RA-68), e cada um tem dono:

| Teste | Ticket |
|---|---|
| ADMINISTRADOR acessa relatório fora de qualquer Cadeia de permissão | [13](issues/13-cadeia-de-permissao-e-listagem.md) |
| Cabeçalho aparece exatamente uma vez no XLSX de **cada** relatório | [16](issues/16-exportacao-xlsx-continua.md), herdado por 23–26 |
| GERENTE não promove ninguém, nem manipulando a requisição | [21](issues/21-gestao-de-acesso-pelo-gerente.md) |
| Execução reservada que nunca iniciou é encerrada pelo callback | [12](issues/12-dag-reserva-pool-e-callback-de-falha.md) |

## Os tickets

**Fundações**

| # | Ticket | Bloqueado por |
|---|---|---|
| 01 | [Fundações do mono repositório e CI verde](issues/01-fundacoes-do-monorepo-e-ci.md) | — |
| 02 | [Ambiente local em Docker Compose](issues/02-ambiente-local-docker-compose.md) | 01 |
| 03 | [Artefatos de arquitetura faltantes: C4 e riscos](issues/03-c4-e-riscos.md) | — |
| 04 | [Fluxos principais e design system](issues/04-fluxos-e-design-system.md) | — |

**Esqueleto vertical e costuras**

| # | Ticket | Bloqueado por |
|---|---|---|
| 05 | [Schema de controle e publicação do catálogo](issues/05-schema-de-controle-e-publicacao-do-catalogo.md) | 01, 02 |
| 06 | [Bootstrap da API: sondas, contrato de erro e Correlation ID](issues/06-bootstrap-da-api-erro-e-correlation-id.md) | 01, 02 |
| 07 | [Caminho único de telemetria](issues/07-caminho-unico-de-telemetria.md) | 02, 06 |
| 08 | [Identidade: realm, perfis, cliente de roles e JWT](issues/08-identidade-realm-perfis-e-jwt.md) | 02, 06 |

**Coleta**

| # | Ticket | Bloqueado por |
|---|---|---|
| 09 | [Coleta ponta a ponta de um relatório da Poupança](issues/09-coleta-ponta-a-ponta-poupanca.md) | 02, 05 |
| 10 | [Desfechos não-felizes da Coleta](issues/10-desfechos-nao-felizes-da-coleta.md) | 09 |
| 11 | [Retentativa, vigência e unicidade](issues/11-retentativa-vigencia-e-unicidade.md) | 10 |
| 12 | [DAG: reserva do ciclo, pool, `catchup=False` e callback de falha](issues/12-dag-reserva-pool-e-callback-de-falha.md) | 02, 05 |
| 19 | [Reprocessamento forçado ponta a ponta](issues/19-reprocessamento-forcado.md) | 11, 12, 13 |

**Exportação e entrega**

| # | Ticket | Bloqueado por |
|---|---|---|
| 13 | [Cadeia de permissão e listagem](issues/13-cadeia-de-permissao-e-listagem.md) | 08, 09 |
| 14 | [Exportação CSV e registro de Download](issues/14-exportacao-csv-e-registro-de-download.md) | 13 |
| 15 | [Exportação PDF e DOCX, com semáforo](issues/15-exportacao-pdf-docx-e-semaforo.md) | 14 |
| 16 | [Exportação XLSX contínua e o teste de cabeçalho único](issues/16-exportacao-xlsx-continua.md) | 15 |
| 17 | [Histórico de downloads](issues/17-historico-de-downloads.md) | 14 |
| 18 | [Retenção, expurgo e indisponibilidade explícita](issues/18-retencao-expurgo-e-indisponibilidade.md) | 14 |

**Catálogo e acesso**

| # | Ticket | Bloqueado por |
|---|---|---|
| 20 | [Catálogo administrável](issues/20-catalogo-administravel.md) | 05, 13 |
| 21 | [Gestão de acesso pelo GERENTE](issues/21-gestao-de-acesso-pelo-gerente.md) | 08, 13 |
| 22 | [Usuários administrativos e senha](issues/22-usuarios-administrativos-e-senha.md) | 08, 13 |

**Demais produtos e medição**

| # | Ticket | Bloqueado por |
|---|---|---|
| 23 | [Produto CLIENTE](issues/23-produto-cliente.md) | 12, 16 |
| 24 | [Produto CONTACORRENTE](issues/24-produto-contacorrente.md) | 12, 16 |
| 25 | [Produto CONSORCIO](issues/25-produto-consorcio.md) | 12, 16 |
| 26 | [Produto EMPRESTIMO](issues/26-produto-emprestimo.md) | 12, 16 |
| 27 | [Métricas de PRD §6 e painéis](issues/27-metricas-e-paineis.md) | 07, 12, 15 |

**Frontend e verificação**

| # | Ticket | Bloqueado por |
|---|---|---|
| 28 | [Shell Angular, OIDC e componentes canônicos](issues/28-shell-angular-oidc-e-componentes-canonicos.md) | 04, 08 |
| 29 | [Telas do RELATOR](issues/29-telas-do-relator.md) | 16, 18, 28 |
| 30 | [Telas do GERENTE](issues/30-telas-do-gerente.md) | 21, 28 |
| 31 | [Telas do ADMINISTRADOR](issues/31-telas-do-administrador.md) | 17, 19, 20, 22, 28 |
| 32 | [E2E: Newman + psql e fluxos críticos no navegador](issues/32-e2e-newman-e-playwright.md) | 29, 31 |
| 33 | [Spike de calibração com `k6`](issues/33-spike-de-calibracao-k6.md) | 16 |

## Três arestas que não são acidente

- **04 bloqueia 28.** O guia trata `fluxos.md` e `design-system.md` como pré-requisito de E3, e a
  especificação §6 repete. Sem eles, a primeira tela nasce fora do padrão.
- **16 bloqueia os quatro produtos.** A convenção de autoria do JRXML precisa existir e estar testada
  **antes** de alguém escrever mais oito relatórios — senão ela apodrece exatamente como ADR-0006
  prevê.
- **33 não bloqueia ninguém.** Enquanto o spike não rodar, os números `PROVISÓRIO` de PRD §10 são
  alvo de calibração e **não** critério de reprovação de PR (especificação §5.5).
