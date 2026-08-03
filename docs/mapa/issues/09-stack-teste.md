# 09 — Stack: teste (H2 vs Testcontainers, Cucumber, Newman, Playwright)

Type: research
Status: resolved
Blocked by: —

## Question

Qual a stack de teste, e o H2 em modo PostgreSQL se sustenta?

A análise comportamental chama o H2 de "ponto mais frágil": migrações Flyway com `jsonb`, tipos nativos, `ON CONFLICT` ou funções do PostgreSQL simplesmente não rodam no H2, e a divergência aparece tarde.

Levantar com fontes primárias (use context7) e recomendar:

- **H2 em modo PostgreSQL vs Testcontainers**: o que exatamente o modo de compatibilidade do H2 cobre e o que não cobre. Custo real do Testcontainers no CI (tempo de subida, reuso de container, Docker-in-Docker no GitHub Actions).
- **JUnit 5 + Cucumber**: versões, integração com Spring Boot Test, organização dos `.feature`, e como rodar cenários Gherkin de **aceitação** e de **integração** (o documento exige Gherkin para todo comportamento observável pelo negócio, inclusive a Coleta).
- **Testar Spring Batch**: `spring-batch-test`, `JobLauncherTestUtils`, e como testar um job que lê de um schema transacional e escreve em MinIO.
- **Newman**: rodar coleções Postman no CI junto com `psql` para asserções em banco.
- **Playwright**: E2E de navegador contra o Angular, em ambiente headless ARM64 (o ambiente já tem Chromium em `/opt/ms-playwright`).
- **MinIO em teste**: Testcontainers, container do Compose, ou um stub S3.
- **JaCoCo**: agregação e metas de cobertura por camada.

Registrar as descobertas em `docs/mapa/research/09-teste.md`.

## Answer

**O H2 não se sustenta — sai da stack.** Pesquisa completa em [`../research/09-teste.md`](../research/09-teste.md).

- **Falha silenciosa, não ruidosa.** O H2 2.4.240 em `MODE=PostgreSQL` aceita `CREATE TABLE ... jsonb` sem erro, converte a coluna para o seu `json` (byte[]) e, no mesmo `INSERT '{"a":1}'`, grava uma **string JSON escapada** onde o PostgreSQL grava o **objeto**. Nenhum erro em lugar nenhum: o teste fica verde e a produção guarda outra coisa. Medido, não suposto.
- **O que quebra alto:** `ON CONFLICT (cols) DO NOTHING/DO UPDATE` (o H2 só suporta `ON CONFLICT DO NOTHING` sem colunas), `->>`, `@>`, `jsonb_*`, `RETURNING`, `text[]`, índice GIN, `timestamptz`, plpgsql, `CREATE EXTENSION`, particionamento, coluna gerada `STORED`. O upsert é o idioma natural da regra `data_referencia + codigo_relatorio` única.
- **Nem o `JobRepository` é igual:** o Spring Batch versiona `schema-h2.sql` ≠ `schema-postgresql.sql` (tipos, identity, sequências divergem).
- **O custo do Testcontainers não se confirma:** medido em ARM64 neste ambiente — **~2 s** com imagem em cache, **~13 s** a frio (pull + subida). Docker já vem no runner `ubuntu-24.04-arm`, gratuito em repo público; **não** precisa Docker-in-Docker. Reuso de container **não** é a saída (a doc diz "not suited for CI usage"); a saída é **singleton container** + `@ServiceConnection`.
- **Correções de versão que a spec precisa absorver:** `JobLauncherTestUtils` → **`JobOperatorTestUtils`** (Spring Batch 6); módulos do Testcontainers 2.x renomeados para **`testcontainers-postgresql` / `testcontainers-minio`**; "JUnit 5" hoje é Jupiter **6.0.3** (herde do BOM); `cucumber-bom` **7.34.6** à parte.
- **Demais decisões:** Cucumber via JUnit Platform Suite com separação aceitação/integração por tag e `@isolated` para paralelismo; MinIO com `MinIOContainer` na integração e Compose no E2E (stub nunca — não prova round-trip de desserialização nem expiração casada); Newman + `psql -v ON_ERROR_STOP=1` como smoke do ambiente montado, não como segunda suíte de regra de negócio; Playwright só no que exige navegador (ARM64 é suportado, Alpine não); JaCoCo com `report-aggregate` e agente ativo no `failsafe`.
