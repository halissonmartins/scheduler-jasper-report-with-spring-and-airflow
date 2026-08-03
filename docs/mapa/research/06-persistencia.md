# 06 — Stack de persistência: PostgreSQL, Flyway, jsonb

Pesquisa de fontes primárias para o ticket [`06-stack-persistencia.md`](../issues/06-stack-persistencia.md).
Data: 2026-08-02. Fontes consultadas via MCP context7 (documentação oficial e código-fonte) e páginas oficiais.

Escopo: este documento decide **versões, tipos de armazenamento, ferramenta de migração, API de acesso a dados e dimensionamento de pool**.
Ele **não** define o DDL do schema de controle (ticket 04), nem a estratégia de teste (ticket 09), nem o contrato do CSV (ticket 23) — apenas registra as consequências dessas escolhas para eles.

---

## 1. PostgreSQL: versão a fixar em produção e nos testes

### O que a política oficial diz

- O PostgreSQL lança uma **major por ano** e **minors a cada três meses no mínimo**; cada major é suportada por **5 anos**. — [Versioning Policy](https://www.postgresql.org/support/versioning/)
- Majors suportadas hoje e seus EOLs: **18 (18.4) → 14/11/2030**, 17 (17.10) → 08/11/2029, 16 (16.14) → 09/11/2028, 15 → 11/11/2027, 14 → 12/11/2026. — [Versioning Policy](https://www.postgresql.org/support/versioning/)
- Upgrade de **minor** é troca de binário + restart; upgrade de **major** exige `pg_upgrade` ou dump/reload. — [Versioning Policy](https://www.postgresql.org/support/versioning/)

### O que o ambiente e a imagem oferecem

- O ambiente de desenvolvimento tem cliente `psql` 18.4 (ver `CLAUDE.md` do ambiente).
- A imagem oficial `postgres` publica as tags `18.4`, `18.4-trixie`, `18.4-bookworm`, `18.4-alpine` (consulta ao registry: `https://hub.docker.com/v2/repositories/library/postgres/tags?name=18`), e o manifesto de `18.4` inclui `linux/arm64/v8` — requisito porque a VM de produção do projeto e o ambiente de build são ARM64.

### O que a versão 18 traz que interessa a este projeto

- **`uuidv7()`** nativo — UUID ordenado por tempo (timestamp ms + sub-ms + aleatório), ideal para chave primária de tabelas de execução/histórico sem fragmentar índice B-tree como o `uuidv4()`/`gen_random_uuid()`. — [9.14. UUID Functions](https://www.postgresql.org/docs/18/functions-uuid.html)
- **Colunas geradas virtuais** passam a ser o padrão (`GENERATED ALWAYS AS (...)` sem `STORED` é virtual, calculado na leitura, sem ocupar disco); `STORED` continua disponível e é calculado na escrita. Virtuais são restritas a funções e tipos embutidos. — [5.4. Generated Columns](https://www.postgresql.org/docs/18/ddl-generated-columns.html) e [CREATE TABLE](https://www.postgresql.org/docs/18/sql-createtable.html)

### Suporte das ferramentas à 18

- Flyway: o código do dialeto declara mínimo absoluto 9.0, mínimo 10 para a edição Community, e **18 como a última major verificada**. — [`PostgreSQLDatabase.ensureSupported()`](https://github.com/flyway/flyway/blob/main/flyway-database/flyway-database-postgresql/src/main/java/org/flywaydb/database/postgresql/PostgreSQLDatabase.java)
- Driver: o Spring Boot 4.1.0 gerencia `org.postgresql:postgresql` **42.7.11**. — [Dependency versions](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html)

### Trade-off e critério

| Opção | A favor | Contra |
|---|---|---|
| **PostgreSQL 18** | janela de suporte até 2030; `uuidv7()` nativo; colunas geradas virtuais; alinhado ao cliente 18.4 do ambiente | major mais nova — extensões de terceiros e ferramentas de backup podem demorar a homologar |
| PostgreSQL 17 | um ano a mais de rodagem em produção no mercado | EOL um ano antes; sem `uuidv7()` nativo (exigiria extensão ou geração na aplicação) |

**Critério de decisão**: como o projeto não depende de nenhuma extensão fora do core (nada de PostGIS, TimescaleDB, `pg_partman`) e o `uuidv7()` resolve a chave das tabelas de execução sem código, **18 é a escolha**. Se surgir dependência de extensão sem build para 18, cair para 17 é uma mudança de tag, não de arquitetura.

**Regra de fixação**: fixar a **minor exata** (`postgres:18.4-trixie`) — e não `postgres:18` — na produção, no Compose de desenvolvimento e nos testes. A mesma tag deve ser usada pelo Testcontainers (o *como* é do ticket 09); versão de banco divergente entre teste e produção é exatamente a classe de bug que a análise comportamental aponta na seção 6.

---

## 2. `jsonb` vs colunas tipadas para os dados coletados

### Primeiro: onde estão os "dados não estruturados"

A frase do documento — "yyyy-MM-dd → nome do produto → código do relatório → **estrutura com os dados não estruturados**" — está na seção **"Estrutura de armazenamento dos dados dos relatórios"**, que descreve o **caminho no MinIO**, não uma tabela. Os dados não estruturados são os artefatos: o `.jrprint` (serialização Java binária) e o `.csv.gz`. Nenhum dos dois é candidato a coluna de banco:

- o `.jrprint` é binário opaco, só faz sentido desserializado pelo JasperReports (e o ticket 18 trata do risco disso);
- o `.csv.gz` já é o dataset da query principal, gravado no momento da coleta, e vai para o MinIO com ciclo de vida de 7 dias.

Portanto **a pergunta "jsonb ou colunas tipadas para os dados coletados" só é real se alguém propuser persistir o dataset também no PostgreSQL** — o que duplicaria o artefato do MinIO, com retenção diferente, e sem requisito que justifique. O que de fato pode ser `jsonb` é um conjunto pequeno e bem delimitado de campos do **schema de controle** (ticket 04): parâmetros do relatório passados pela DAG, detalhe estruturado de erro, contexto do reprocessamento, e eventualmente o resumo do fill (contagem de linhas por dataset).

### O que a documentação diz sobre indexação de `jsonb`

- Índice GIN padrão (`jsonb_ops`) indexa os operadores `@>`, `@?`, `@@`, `?`, `?|`, `?&`. O `jsonb_path_ops` indexa **apenas** `@>`, `@?`, `@@` — não suporta os operadores de existência de chave — mas gera índice menor e mais rápido para o que suporta. — [64.3. GIN — Built-in Operator Classes](https://www.postgresql.org/docs/18/gin.html) e [8.14.4. jsonb Indexing](https://www.postgresql.org/docs/18/datatype-json.html)

```sql
CREATE INDEX idxgin  ON api USING GIN (jdoc);                  -- jsonb_ops (padrão)
CREATE INDEX idxginp ON api USING GIN (jdoc jsonb_path_ops);   -- containment/jsonpath
CREATE INDEX idxgintags ON api USING GIN ((jdoc -> 'tags'));   -- índice de expressão, chave específica
```
— [8.14. JSON Types](https://www.postgresql.org/docs/18/datatype-json.html)

- Consultas indexáveis usam containment e jsonpath: `jdoc @> '{"company":"Magnafone"}'`, `jdoc @? '$.tags[*] ? (@ == "qui")'`. — [8.14. JSON Types](https://www.postgresql.org/docs/18/datatype-json.html)

### O que a documentação diz sobre projeto de documentos JSON

- "É recomendável manter um schema previsível para simplificar consultas e sumarização"; JSON está sujeito ao **controle de concorrência normal — uma atualização adquire lock de linha sobre o documento inteiro**; por isso convém **limitar o tamanho dos documentos** e garantir que representem dado atômico. — [8.14.5. Designing JSON Documents](https://www.postgresql.org/docs/18/datatype-json.html)
- Armazenamento: valores grandes vão para TOAST, fatiados em chunks de ~2000 bytes, com ponteiro de 18 bytes na linha principal; o modo padrão para tipos variáveis é `EXTENDED` (fora de linha + comprimido) e pode ser alterado por coluna. — [73.2. TOAST](https://www.postgresql.org/docs/18/storage-toast.html) e [ALTER TABLE ... SET STORAGE](https://www.postgresql.org/docs/18/sql-altertable.html)
- Para medir o custo real: `pg_column_size()`, `pg_column_compression()`, `pg_column_toast_chunk_id()`. — [9.28. System Administration Functions](https://www.postgresql.org/docs/18/functions-admin.html)

### Meio-termo: promover chaves do `jsonb` a colunas

Uma chave do documento pode virar coluna gerada e ser indexada como coluna comum:

```sql
ALTER TABLE execucao
  ADD COLUMN dag_run_id text
  GENERATED ALWAYS AS (parametros ->> 'dag_run_id') STORED;
```
`STORED` é calculado na escrita e ocupa disco; virtual é calculado na leitura e não ocupa. — [5.4. Generated Columns](https://www.postgresql.org/docs/18/ddl-generated-columns.html). Use `STORED` quando o objetivo é indexar/filtrar; as virtuais têm restrições adicionais (só funções e tipos embutidos).

### Consequências por eixo

| Eixo | Colunas tipadas | `jsonb` |
|---|---|---|
| **Indexação** | B-tree comum; estatísticas por coluna; ordenação e faixa sem esforço | GIN (`jsonb_ops` ou `jsonb_path_ops`), índice de expressão por chave, ou coluna gerada `STORED`; ordenação/faixa exigem extrair a chave |
| **Migração** | `ALTER TABLE` versionado no Flyway; o DDL é o contrato e o banco recusa dado fora dele | não há DDL a alterar — a mudança de forma vira `UPDATE` com funções `jsonb` e o contrato passa a viver no código Java; *schema drift* silencioso |
| **Exportador CSV** | ordem e tipo das colunas vêm do catálogo; nulo é nulo | é preciso reconstruir ordem e tipos na leitura, e "chave ausente" ≠ "chave nula" — ambiguidade que vaza para o CSV (ticket 23) |
| **Concorrência** | update de um campo trava a linha, mas o campo é pequeno | update de qualquer chave trava e reescreve o documento inteiro ([8.14.5](https://www.postgresql.org/docs/18/datatype-json.html)) |
| **Teste** | roda em qualquer banco | migrações com `jsonb` **não rodam em H2**, é o ponto que a análise comportamental levanta (seção 6) — reforça Testcontainers (ticket 09) |

### Se `jsonb` for usado com JPA

Hibernate mapeia atributo para coluna `json`/`jsonb` com `@JdbcTypeCode(SqlTypes.JSON)`; exige um serializador em runtime (Jackson ou Yasson) e o tipo JSON só é usado quando explicitamente configurado. — [Hibernate ORM — Basic types / Mapping](https://github.com/hibernate/hibernate-orm/blob/main/documentation/src/main/asciidoc/userguide/chapters/domain/basic_types.adoc)

### Recomendação deste eixo

**Colunas tipadas por padrão; `jsonb` como exceção nomeada.** O schema de controle é um modelo conhecido e estável (execução, relatório, produto, download) — nada nele é "não estruturado". Reserve `jsonb` para dois campos: `parametros_entrada` (o que a DAG mandou, formato ditado pelo Airflow) e `detalhe_erro` (payload variável do erro). Se algum desses campos passar a ser filtrado com frequência, promova a chave a coluna gerada `STORED` e indexe — não crie índice GIN antes de existir a consulta.

---

## 3. Flyway

### Versão

- Última versão publicada no Maven Central: **flyway-core 13.1.0** ([Maven Central](https://central.sonatype.com/artifact/org.flywaydb/flyway-core/versions)).
- Versão **gerenciada pelo BOM do Spring Boot 4.1.0: 12.4.0** ([Dependency versions](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html)).
- **Critério**: usar a versão do BOM. Sobrescrever `flyway.version` só se aparecer necessidade concreta na 13.x — a versão do BOM é a que a auto-configuração do Boot é testada contra.
- O módulo `flyway-database-postgresql` é dependência separada (é `runtime` no `flyway-commandline`) — em projeto Maven com Spring Boot ele precisa estar declarado junto do `flyway-core`. — [`flyway-commandline/pom.xml`](https://github.com/flyway/flyway/blob/main/flyway-commandline/pom.xml)

### Suporte a PostgreSQL

Community: mínimo 10, verificado até a major **18**; URL `jdbc:postgresql://host:port/database`; driver `org.postgresql:postgresql` a partir de `9.3-1104-jdbc4`. — [`PostgreSQLDatabase.java`](https://github.com/flyway/flyway/blob/main/flyway-database/flyway-database-postgresql/src/main/java/org/flywaydb/database/postgresql/PostgreSQLDatabase.java) e [PostgreSQL Database — Driver Reference](https://github.com/flyway/flyway/blob/main/documentation/Reference/Database Driver Reference/PostgreSQL Database.md)

### Múltiplos schemas

Duas configurações distintas, que respondem a perguntas diferentes:

- `flyway.schemas` (lista separada por vírgula, também via `FLYWAY_SCHEMAS`) e `flyway.defaultSchema` — o *defaultSchema* é onde a tabela de histórico vive e qual schema fica no `search_path` durante a migração. — [Default Schema Setting](https://github.com/flyway/flyway/blob/main/documentation/Reference/Configuration/Flyway%20Namespace/Flyway%20Default%20Schema%20Setting.md), [Environment Schemas Setting](https://github.com/flyway/flyway/blob/main/documentation/Reference/Configuration/Environments%20Namespace/Environment%20Schemas%20Setting.md)
- Para **schemas com ciclos de vida autônomos**, a própria FAQ do Flyway manda usar **instâncias separadas**, cada uma com seu `locations`, seu `schemas` e sua **própria tabela de histórico**:

```text
locations = /sql/foo     |  locations = /sql/bar
schemas   = foo          |  schemas   = bar
table     = flyway_schema_history
```
— [Frequently Asked Questions](https://github.com/flyway/flyway/blob/main/documentation/Reference/Usage/Frequently%20Asked%20Questions.md)

Este é exatamente o caso das **três naturezas** do ticket: os schemas transacionais por produto, o schema de controle e o JobRepository do Spring Batch evoluem em ritmos diferentes e são de donos diferentes.

### `baselineOnMigrate`

Executa um `baseline` automático quando o `migrate` roda contra um schema **não vazio e sem tabela de histórico**, marcando tudo até a `baselineVersion` como já aplicado. — [Baseline On Migrate Setting](https://github.com/flyway/flyway/blob/main/documentation/Reference/Configuration/Flyway%20Namespace/Flyway%20Baseline%20On%20Migrate%20Setting.md); uso típico em linha de comando: `flyway migrate -baselineOnMigrate=true -environment=prod`.

**Recomendação**: manter `baselineOnMigrate=false` (padrão) em todos os ambientes. O projeto nasce agora — todo schema começa vazio e todas as migrações são versionadas desde a V1. Ligar `baselineOnMigrate` é como esconder um schema que alguém criou à mão; é o que produz "funciona na minha máquina" com banco divergente. A exceção legítima é adotar um banco legado, que não existe aqui.

### Callbacks

Eventos do comando `migrate`: `beforeMigrate`, `beforeEachMigrate`, `afterEachMigrate`, `afterEachMigrateError`, `afterMigrate`, `afterMigrateApplied`, `afterMigrateError`. — [Callback Events](https://github.com/flyway/flyway/blob/main/documentation/Reference/Callback%20Events/Callback%20Events%20-%20Native%20Connectors.md); a ordem real de disparo está em [`DbMigrate.java`](https://github.com/flyway/flyway/blob/main/flyway-core/src/main/java/org/flywaydb/core/internal/command/DbMigrate.java).
Duas formas: arquivo SQL com o nome do evento (`afterMigrate.sql`) no `locations`, ou implementar a interface `Callback` (métodos `supports`, `canHandleInTransaction`, `handle`, `getCallbackName`; callbacks são ordenados alfabeticamente pelo nome). — [API Hooks](https://github.com/flyway/flyway/blob/main/documentation/Reference/Usage/API%20(Java)/API%20Hooks.md)

**Uso recomendado aqui**: `afterMigrate.sql` por schema para reaplicar `GRANT`s idempotentes (ex.: dar `SELECT` ao usuário da API sobre tudo que existe no schema de controle) — assim uma tabela nova não nasce inacessível porque alguém esqueceu o grant na migração. Não usar callback para carregar dado de negócio; dado de teste é migração versionada em `src/test/resources`.

### Organização das três naturezas

| Natureza | Quem roda | Onde ficam as migrações | Tabela de histórico |
|---|---|---|---|
| Schema transacional do produto X | módulo processador X (ou um módulo `db-<produto>` dedicado) | `classpath:db/migration/<produto>` | no schema do produto |
| Schema de controle | **um dono só** — recomendo o módulo API REST, que sobe primeiro e é único | `classpath:db/migration/controle` | no schema de controle |
| JobRepository do Spring Batch | Starter do processador | `classpath:db/migration/batch` | no schema do batch |

Pontos de apoio na documentação:

- Spring Boot permite `spring.flyway.locations` com múltiplos caminhos e com o placeholder `{vendor}`; e definir `spring.flyway.url`/`user`/`password` faz o Flyway usar um **DataSource próprio**, separado do da aplicação. — [How-to: Data initialization](https://github.com/spring-projects/spring-boot/blob/v4.0.3/documentation/spring-boot-docs/src/docs/antora/modules/how-to/pages/data-initialization.adoc)
  Isso resolve o requisito de **credencial de migração com DDL separada da credencial de runtime**: o app conecta como usuário sem `CREATE`, o Flyway conecta como dono do schema.
- Spring Batch: o DDL do JobRepository é publicado no apêndice de schema (`BATCH_JOB_INSTANCE`, `BATCH_JOB_EXECUTION`, …) e a configuração aceita `tablePrefix`, `maxVarCharLength` e `isolationLevelForCreate` via `@EnableJdbcJobRepository`. — [Schema Appendix](https://github.com/spring-projects/spring-batch/blob/v6.0.3/spring-batch-docs/modules/ROOT/pages/schema-appendix.adoc) e [Configuring the JobRepository](https://github.com/spring-projects/spring-batch/blob/v6.0.3/spring-batch-docs/modules/ROOT/pages/job/configuring-repository.adoc)
- O Spring Boot inicializa esse schema sozinho se `spring.batch.jdbc.initialize-schema=always`, e `never` desliga. — [How-to: Data initialization](https://github.com/spring-projects/spring-boot/blob/v4.0.3/documentation/spring-boot-docs/src/docs/antora/modules/how-to/pages/data-initialization.adoc)

**Recomendação**: `spring.batch.jdbc.initialize-schema=never` e o DDL oficial do Spring Batch copiado para uma migração Flyway versionada (`V1__batch_job_repository.sql`). Motivo: duas ferramentas escrevendo DDL no mesmo banco não têm ordem definida entre si, e um upgrade do Spring Batch que altere o schema passaria despercebido. Com Flyway, o upgrade vira um `V2__...sql` revisável em PR.

### Isolamento e privilégios no PostgreSQL

A regra arquitetural "cada módulo lê exclusivamente do schema do seu produto" é sustentável com recursos nativos:

- `CREATE SCHEMA <nome> AUTHORIZATION <usuario>` cria o schema já com dono restrito. — [5.10. Schemas](https://www.postgresql.org/docs/18/ddl-schemas.html)
- Acesso a objetos de um schema exige `USAGE`; criar objetos exige `CREATE` — e a prática moderna é revogar `CREATE` do `public`. — [5.10.4. Schemas and Privileges](https://www.postgresql.org/docs/18/ddl-schemas.html)
- `ALTER ROLE ALL SET search_path = "$user"` remove o `public` do caminho padrão. — [5.10. Schemas](https://www.postgresql.org/docs/18/ddl-schemas.html)
- `ALTER DEFAULT PRIVILEGES IN SCHEMA ... GRANT SELECT ON TABLES TO ...` faz o grant valer para tabelas futuras. — [ALTER DEFAULT PRIVILEGES](https://www.postgresql.org/docs/18/sql-alterdefaultprivileges.html)

Ou seja: **isolamento por credencial, não por convenção**. Um usuário por processador com acesso só ao seu schema transacional + escrita no controle; um usuário da API com `SELECT` no controle e nenhum acesso aos transacionais. O detalhamento pertence ao ticket 04, mas a viabilidade está provada aqui.

---

## 4. Acesso a dados: Spring Data JPA, JdbcTemplate/JdbcClient ou jOOQ

### O fato decisivo para a leitura em chunk (pgjdbc)

O driver PostgreSQL **por padrão traz o ResultSet inteiro para a memória do cliente**. O modo cursor só é ativado se **todas** as condições valerem: protocolo V3, **autocommit desligado**, `Statement` `TYPE_FORWARD_ONLY`, consulta de **um único statement**, e `setFetchSize(n)` com `n > 0`. Se alguma falhar, o driver **silenciosamente** volta ao fetch completo. — [pgJDBC — Getting results based on a cursor](https://github.com/pgjdbc/pgjdbc/blob/master/docs/content/documentation/query.md)

Essa é a origem do OOM clássico em batch: "o `ItemReader` é streaming" na cabeça do desenvolvedor, e no driver não é. Também vale notar que `refcursor` retornado por função **cacheia tudo no cliente independentemente do fetch size**. — [pgJDBC — callproc](https://github.com/pgjdbc/pgjdbc/blob/master/docs/content/documentation/callproc.md)

### Cursor vs paginação no Spring Batch

- `JdbcCursorItemReader` opera diretamente sobre um `ResultSet` a partir de um SQL, com `DataSource` e `RowMapper`. — [Readers and Writers — Database](https://github.com/spring-projects/spring-batch/blob/v6.0.3/spring-batch-docs/modules/ROOT/pages/readers-and-writers/database.adoc)
- `JdbcPagingItemReader` lê em páginas via `SqlPagingQueryProviderFactoryBean`, exigindo `selectClause`, `fromClause`, `sortKey` e `pageSize`. — [Readers and Writers — Database](https://github.com/spring-projects/spring-batch/blob/v6.0.3/spring-batch-docs/modules/ROOT/pages/readers-and-writers/database.adoc)

| Critério | `JdbcCursorItemReader` | `JdbcPagingItemReader` |
|---|---|---|
| Conexão | mantém uma conexão e um cursor abertos durante todo o step | uma consulta curta por página; conexão devolvida ao pool entre páginas |
| Requisitos escondidos | depende das 4 condições do pgjdbc acima; erra em silêncio se alguma faltar | nenhum requisito de driver |
| Restart | o cursor não sobrevive ao restart; reposiciona relendo | reposiciona pela `sortKey`, naturalmente |
| Correção do resultado | snapshot consistente dentro da transação | páginas em transações diferentes — exige `sortKey` estável e única, e a tabela não pode estar sofrendo escrita concorrente relevante |
| Custo | uma varredura | N consultas com `OFFSET`/keyset — mais trabalho no banco |

**Critério de decisão**: a coleta lê **base transacional grande** e é a única fronteira de leitura (ninguém mais escreve enquanto ela roda, e a data de referência delimita o conjunto). Com esse recorte, `JdbcPagingItemReader` com `sortKey` na chave primária é a escolha mais segura — não depende de um comportamento de driver que falha em silêncio e é restartável. Onde a query for comprovadamente grande e o snapshot importar, `JdbcCursorItemReader` é aceitável **desde que** `fetchSize` seja explicitamente configurado e haja um teste que prove o consumo de memória.

### API REST

`JdbcClient` (Spring Framework **6.1+**) unifica statements com parâmetros nomeados (antes `NamedParameterJdbcTemplate`) e posicionais (`JdbcTemplate`) numa API fluente. — [Data Access — JDBC Core](https://docs.spring.io/spring-framework/reference/data-access/jdbc/core.html)

As consultas da API são listagens simples (relatórios disponíveis por data/produto, status de execução, histórico de downloads) — projeções de leitura, não navegação de grafo de objetos. `JdbcClient` entrega isso com SQL explícito e sem `EntityManager`.

### jOOQ

- Apenas a **Open Source Edition** está no Maven Central (`org.jooq:jooq`, hoje **3.21.5**, também a versão gerenciada pelo Spring Boot 4.1.0); as edições comerciais (`org.jooq.pro*`) vêm de repositório próprio. — [Getting jOOQ](https://www.jooq.org/doc/3.21/manual/getting-started/getting-jooq) e [Dependency versions](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html)
- PostgreSQL é banco open source e portanto atendido pela edição gratuita; a OSS Edition compila e roda em Java 8+. — [Build your own](https://www.jooq.org/doc/3.21/manual/getting-started/build-your-own)
- Custo real: exige **geração de código** a partir de um banco (ou DDL) durante o build. — [Code generation with Maven](https://www.jooq.org/doc/3.21/manual/code-generation/codegen-execution/codegen-maven)

**Critério**: adotar jOOQ implica ter, no build de cada módulo, um banco migrado pelo Flyway para gerar as classes — no CI isso é um container a mais por módulo. Ganho: SQL tipado em compilação. Para consultas de listagem e uma query de relatório por módulo, o ganho não paga o acréscimo de pipeline. **Não adotar agora**; reconsiderar se as queries dos relatórios crescerem em complexidade (a decisão é reversível por módulo, já que jOOQ e `JdbcClient` convivem sobre o mesmo `DataSource`).

### Spring Data JPA

Cabe onde há CRUD de entidades com identidade e ciclo de vida: cadastro de produtos, relatórios, grupos — telas de administração, volume baixo. Não cabe no `ItemReader` do batch (a persistência de contexto acumula entidades e vira consumo de heap) nem nas listagens de leitura da API. Se for usado com `jsonb`, o mapeamento é `@JdbcTypeCode(SqlTypes.JSON)` e exige Jackson/Yasson em runtime. — [Hibernate ORM — Mapping](https://github.com/hibernate/hibernate-orm/blob/main/documentation/src/main/asciidoc/introduction/Mapping.adoc)

---

## 5. Pool de conexões e N containers batch simultâneos

### Limites do servidor

- `max_connections` tem **padrão 100**; aumentar consome mais memória compartilhada e **exige restart** do servidor. — [Connection Settings](https://www.postgresql.org/docs/current/runtime-config-connection.html)
- A fila de conexões do kernel (`net.core.somaxconn`) costuma ser 128 — rajadas de conexão acima disso resultam em "Connection refused". — [Kernel Resources](https://www.postgresql.org/docs/current/kernel-resources.html)

### O que o HikariCP recomenda

- Princípio: **pool pequeno, saturado de threads esperando**. Poucas dezenas de conexões bastam mesmo com muitos usuários; o tamanho ótimo fica perto do número de consultas que o banco processa simultaneamente, tipicamente `núcleos * 2`. — [About Pool Sizing](https://github.com/brettwooldridge/hikaricp/wiki/About-Pool-Sizing)
- Fórmula do projeto PostgreSQL como ponto de partida: `connections = ((core_count * 2) + effective_spindle_count)`, com `core_count` sem Hyper-Threading e `effective_spindle_count` tendendo a zero quando o dataset ativo cabe em cache. Exemplo do wiki: servidor de 4 núcleos e 1 disco → pool de 9 a 10, e o desempenho **piora** ao ultrapassar isso. — [About Pool Sizing](https://github.com/brettwooldridge/hikaricp/wiki/About-Pool-Sizing)
- Fórmula anti-deadlock: `pool = T_n * (C_m - 1) + 1`, onde `T_n` é o número máximo de threads e `C_m` o máximo de conexões simultâneas seguradas por **uma** thread. É o mínimo para não travar, não o ótimo. — [About Pool Sizing](https://github.com/brettwooldridge/hikaricp/wiki/About-Pool-Sizing)
- Versão gerenciada: `com.zaxxer:HikariCP` **7.0.2** no Spring Boot 4.1.0. — [Dependency versions](https://docs.spring.io/spring-boot/appendix/dependency-versions/coordinates.html)

### Aplicando ao desenho deste sistema

Um container processador precisa de **dois `DataSource` lógicos**: leitura do schema transacional do produto e escrita no schema de controle + JobRepository (credenciais diferentes, ver seção 3). Numa `Step` chunk-oriented, a thread do step segura a conexão da transação de escrita **e** a conexão de leitura ao mesmo tempo → `C_m = 2`. Com um step de thread única, `T_n = 1` e o mínimo anti-deadlock é `1*(2-1)+1 = 2` conexões **por pool**.

Orçamento de conexões (valores propostos, a validar em carga):

| Consumidor | Instâncias | Pool cada | Total |
|---|---|---|---|
| Container processador (pool transacional) | 5 simultâneos | 4 | 20 |
| Container processador (pool controle/batch) | 5 simultâneos | 4 | 20 |
| API REST | 2 | 10 | 20 |
| Flyway na subida (transiente) | — | — | ~5 |
| Superusuários reservados (`superuser_reserved_connections`) | — | — | 3 |
| **Total** | | | **~68 de 100** |

Observações que decorrem disso:

1. **O limite é o número de containers simultâneos, não o pool de cada um.** O Airflow controla a concorrência (paralelismo da DAG / pool do Airflow) — esse é o botão real, e pertence ao ticket 13/19. A regra a escrever na spec: `containers_simultâneos * (pool_transacional + pool_controle) + api * pool_api < max_connections - reserva`.
2. **O banco de metadados do Airflow deve ser instância separada** (ou ao menos database separado com orçamento próprio). Airflow abre conexões de forma agressiva com schedulers e workers; misturá-lo ao orçamento acima estoura a conta sem aviso.
3. **`connectionTimeout` curto e falha explícita** é preferível a fila infinita: com o container batch, esperar 30s por conexão e falhar é diagnóstico; esperar indefinidamente aparece como job "em processamento" eterno — exatamente o estado que a análise comportamental aponta como indistinguível de um job saudável e lento.
4. **PgBouncer não é necessário agora** (5 produtos, containers de vida curta, ~68 conexões). Vira necessário se o número de produtos ou o paralelismo por produto crescer; registrar como ponto de reavaliação, não implementar.
5. `isolationLevelForCreate` do JobRepository é `SERIALIZABLE` por padrão, para garantir que só um processo consiga criar a mesma `JobInstance` concorrentemente — **manter o padrão**, porque é justamente ele que protege contra duas DAGs disparando o mesmo par (data de referência, código do relatório). — [Configuring the JobRepository](https://github.com/spring-projects/spring-batch/blob/v6.0.3/spring-batch-docs/modules/ROOT/pages/job/configuring-repository.adoc)

---

## Recomendação

1. **PostgreSQL 18, minor fixa `18.4`** — imagem `postgres:18.4-trixie` (manifesto com `linux/arm64/v8`), a mesma tag em produção, no Compose de desenvolvimento e nos testes. Janela de suporte até 14/11/2030, `uuidv7()` nativo para as chaves das tabelas de execução e histórico. Fallback para 17 só se aparecer dependência de extensão sem build para 18.
2. **Colunas tipadas por padrão.** Os "dados não estruturados" da descrição são os artefatos no MinIO (`.jrprint`, `.csv.gz`), não linhas de banco — não replicar o dataset no PostgreSQL. `jsonb` fica restrito a `parametros_entrada` e `detalhe_erro` no schema de controle. Sem índice GIN até existir a consulta; quando existir, promover a chave a coluna gerada `STORED` e indexar com B-tree, ou usar `jsonb_path_ops` se o acesso for por containment.
3. **Flyway na versão do BOM do Spring Boot (12.4.0)**, com `flyway-database-postgresql` declarado. **Uma instância Flyway por natureza de schema**, cada uma com seu `locations`, seu `defaultSchema` e sua própria tabela de histórico: transacional por produto (dono: o módulo do produto), controle (dono: a API REST), JobRepository (dono: o Starter). `baselineOnMigrate=false` em todos os ambientes. `afterMigrate.sql` por schema apenas para `GRANT`s idempotentes.
4. **JobRepository migrado pelo Flyway**, com `spring.batch.jdbc.initialize-schema=never` — o DDL oficial do Spring Batch entra como `V1` versionada, e `isolationLevelForCreate=SERIALIZABLE` fica no padrão.
5. **Acesso a dados**: `JdbcClient` (Spring 6.1+) na API REST e nas queries de relatório dos processadores; Spring Data JPA apenas no CRUD administrativo; **jOOQ não agora** (custa geração de código no build de cada módulo, ganho baixo para o perfil de query atual, decisão reversível).
6. **Leitura em chunk com `JdbcPagingItemReader`** (`sortKey` na PK, `pageSize` alinhado ao `chunk`), porque `JdbcCursorItemReader` depende de quatro condições do pgjdbc (autocommit off, `TYPE_FORWARD_ONLY`, statement único, `fetchSize > 0`) e degrada **em silêncio** para carregar o ResultSet inteiro em memória quando alguma falha.
7. **Pool pequeno e orçamento explícito**: ~4 conexões por pool no container batch (dois pools: transacional e controle), ~10 na API; regra escrita na spec ligando `max_connections` (padrão 100) ao paralelismo permitido no Airflow; banco de metadados do Airflow em instância separada; `connectionTimeout` curto com falha explícita. PgBouncer só se o paralelismo crescer.
8. **Isolamento por credencial, não por convenção**: `CREATE SCHEMA ... AUTHORIZATION`, `USAGE`/`CREATE` explícitos, `public` fora do `search_path`, `ALTER DEFAULT PRIVILEGES` para tabelas futuras, e usuário de migração (com DDL) separado do usuário de runtime via `spring.flyway.url/user/password`.

### Pontos que este documento repassa a outros tickets

- **04 (schema de controle)**: o DDL concreto, quais campos são `jsonb`, e o mapa de usuários/GRANTs por schema.
- **09 (teste)**: a tag `postgres:18.4-trixie` deve ser a mesma no Testcontainers; `jsonb` nas migrações é mais um argumento contra H2.
- **13/19 (Airflow)**: o paralelismo da DAG é o botão que controla o consumo de conexões; o banco do Airflow fica fora deste orçamento.
- **23 (contrato do CSV)**: o CSV nasce da query no momento da coleta; se algum dia vier de `jsonb`, "chave ausente" vs "chave nula" precisa de regra escrita.
