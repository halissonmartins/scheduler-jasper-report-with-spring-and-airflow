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

Quatro frentes ficam livres cedo e correm em paralelo: os documentos de arquitetura e design (03 e
04) e o catálogo seed (05), os três sem bloqueador algum; a Coleta a partir de 06; e a plataforma a
partir de 07.

Quatro tickets ficam livres de uma vez quando 17 fechar: os produtos 24 a 27 são independentes
entre si.

## Onde estão os três cenários canônicos

Não existe teste algum no repositório de onde copiar padrão (especificação §5.4). O **primeiro**
cenário escrito em cada costura vira o molde de todas as sessões seguintes, e por isso os três
carregam peso além do seu tamanho:

| Costura | Ticket | Entra por |
|---|---|---|
| **S1** | [07](issues/07-bootstrap-da-api-erro-e-correlation-id.md) | HTTP na API REST |
| **S2** | [10](issues/10-coleta-ponta-a-ponta-poupanca.md) | invocação do job de coleta do produto |
| **S3** | [13](issues/13-dag-reserva-pool-e-callback-de-falha.md) | DAG, com as tasks de produto em dublê |

Os três precisam ser citados nominalmente no `ARCHITECTURE.md` como implementação de referência.

## Os quatro testes obrigatórios por natureza de risco

São os que ninguém escreve espontaneamente (RA-68), e cada um tem dono:

| Teste | Ticket |
|---|---|
| ADMINISTRADOR acessa relatório fora de qualquer Cadeia de permissão | [14](issues/14-cadeia-de-permissao-e-listagem.md) |
| Cabeçalho aparece exatamente uma vez no XLSX de **cada** relatório | [17](issues/17-exportacao-xlsx-continua.md), herdado por 24–27 |
| GERENTE não promove ninguém, nem manipulando a requisição | [22](issues/22-gestao-de-acesso-pelo-gerente.md) |
| Execução reservada que nunca iniciou é encerrada pelo callback | [13](issues/13-dag-reserva-pool-e-callback-de-falha.md) |

## Os tickets

**Fundações**

| # | Ticket | Bloqueado por |
|---|---|---|
| 01 | [Fundações do mono repositório e CI verde](issues/01-fundacoes-do-monorepo-e-ci.md) | — |
| 02 | [Ambiente local em Docker Compose](issues/02-ambiente-local-docker-compose.md) | 01 |
| 03 | [Artefatos de arquitetura faltantes: C4 e riscos](issues/03-c4-e-riscos.md) | — |
| 04 | [Fluxos principais e design system](issues/04-fluxos-e-design-system.md) | — |
| 05 | [Catálogo seed: os dez relatórios de exemplo e seus modelos de dados](issues/05-catalogo-seed-relatorios-e-modelos-de-dados.md) | — |

**Esqueleto vertical e costuras**

| # | Ticket | Bloqueado por |
|---|---|---|
| 06 | [Schema de controle e publicação do catálogo](issues/06-schema-de-controle-e-publicacao-do-catalogo.md) | 01, 02, 05 |
| 07 | [Bootstrap da API: sondas, contrato de erro e Correlation ID](issues/07-bootstrap-da-api-erro-e-correlation-id.md) | 01, 02 |
| 08 | [Caminho único de telemetria](issues/08-caminho-unico-de-telemetria.md) | 02, 07 |
| 09 | [Identidade: realm, perfis, cliente de roles e JWT](issues/09-identidade-realm-perfis-e-jwt.md) | 02, 07 |

**Coleta**

| # | Ticket | Bloqueado por |
|---|---|---|
| 10 | [Coleta ponta a ponta de um relatório da Poupança](issues/10-coleta-ponta-a-ponta-poupanca.md) | 02, 05, 06 |
| 11 | [Desfechos não-felizes da Coleta](issues/11-desfechos-nao-felizes-da-coleta.md) | 10 |
| 12 | [Retentativa, vigência e unicidade](issues/12-retentativa-vigencia-e-unicidade.md) | 11 |
| 13 | [DAG: reserva do ciclo, pool, `catchup=False` e callback de falha](issues/13-dag-reserva-pool-e-callback-de-falha.md) | 02, 06 |
| 20 | [Reprocessamento forçado ponta a ponta](issues/20-reprocessamento-forcado.md) | 12, 13, 14 |

**Exportação e entrega**

| # | Ticket | Bloqueado por |
|---|---|---|
| 14 | [Cadeia de permissão e listagem](issues/14-cadeia-de-permissao-e-listagem.md) | 09, 10 |
| 15 | [Exportação CSV e registro de Download](issues/15-exportacao-csv-e-registro-de-download.md) | 14 |
| 16 | [Exportação PDF e DOCX, com semáforo](issues/16-exportacao-pdf-docx-e-semaforo.md) | 15 |
| 17 | [Exportação XLSX contínua e o teste de cabeçalho único](issues/17-exportacao-xlsx-continua.md) | 16 |
| 18 | [Histórico de downloads](issues/18-historico-de-downloads.md) | 15 |
| 19 | [Retenção, expurgo e indisponibilidade explícita](issues/19-retencao-expurgo-e-indisponibilidade.md) | 15 |

**Catálogo e acesso**

| # | Ticket | Bloqueado por |
|---|---|---|
| 21 | [Catálogo administrável](issues/21-catalogo-administravel.md) | 06, 14 |
| 22 | [Gestão de acesso pelo GERENTE](issues/22-gestao-de-acesso-pelo-gerente.md) | 09, 14 |
| 23 | [Usuários administrativos e senha](issues/23-usuarios-administrativos-e-senha.md) | 09, 14 |

**Demais produtos e medição**

| # | Ticket | Bloqueado por |
|---|---|---|
| 24 | [Produto CLIENTE](issues/24-produto-cliente.md) | 05, 13, 17 |
| 25 | [Produto CONTACORRENTE](issues/25-produto-contacorrente.md) | 05, 13, 17 |
| 26 | [Produto CONSORCIO](issues/26-produto-consorcio.md) | 05, 13, 17 |
| 27 | [Produto EMPRESTIMO](issues/27-produto-emprestimo.md) | 05, 13, 17 |
| 28 | [Métricas de PRD §6 e painéis](issues/28-metricas-e-paineis.md) | 08, 13, 16 |

**Frontend e verificação**

| # | Ticket | Bloqueado por |
|---|---|---|
| 29 | [Shell Angular, OIDC e componentes canônicos](issues/29-shell-angular-oidc-e-componentes-canonicos.md) | 04, 09 |
| 30 | [Telas do RELATOR](issues/30-telas-do-relator.md) | 17, 19, 29 |
| 31 | [Telas do GERENTE](issues/31-telas-do-gerente.md) | 22, 29 |
| 32 | [Telas do ADMINISTRADOR](issues/32-telas-do-administrador.md) | 18, 20, 21, 23, 29 |
| 33 | [E2E: Newman + psql e fluxos críticos no navegador](issues/33-e2e-newman-e-playwright.md) | 30, 32 |
| 34 | [Spike de calibração com `k6`](issues/34-spike-de-calibracao-k6.md) | 17 |

## Quatro arestas que não são acidente

- **05 bloqueia 06, 10 e 24–27.** Os dez relatórios de exemplo e os modelos de dados eram pendência
  declarada na arquitetura §14 e na especificação §6, e ao mesmo tempo insumo de tickets marcados
  como prontos. Definir vem antes de publicar catálogo e antes de apurar — senão a primeira sessão
  inventa os dez, e a invenção vira fato consumado no molde da costura S2.
- **04 bloqueia 29.** O guia trata `fluxos.md` e `design-system.md` como pré-requisito de E3, e a
  especificação §6 repete. Sem eles, a primeira tela nasce fora do padrão.
- **17 bloqueia os quatro produtos.** A convenção de autoria do JRXML precisa existir e estar testada
  **antes** de alguém escrever mais oito relatórios — senão ela apodrece exatamente como ADR-0006
  prevê.
- **34 não bloqueia ninguém.** Enquanto o spike não rodar, os números `PROVISÓRIO` de PRD §10 são
  alvo de calibração e **não** critério de reprovação de PR (especificação §5.5).
