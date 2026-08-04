# 06 — Stack: persistência (PostgreSQL, Flyway, jsonb)

Type: research
Status: resolved
Blocked by: —

## Question

Qual a stack de persistência e como ela lida com "dados não estruturados"?

Levantar com fontes primárias (use context7) e recomendar:

- **PostgreSQL**: versão a fixar em produção e nos testes (o ambiente tem cliente 18.x).
- **`jsonb` vs colunas tipadas** para os dados coletados. A estrutura de armazenamento fala em "estrutura com os dados não estruturados" — mas o dataset da query principal também vira CSV, o que sugere forma tabular conhecida. Levantar as consequências de cada caminho para indexação, migração e para o exportador CSV.
- **Flyway**: versão, suporte a múltiplos schemas, `baselineOnMigrate`, callbacks, e como organizar migrações de três naturezas (transacional por produto, controle, JobRepository).
- **Acesso a dados**: Spring Data JPA, JdbcTemplate ou jOOQ nos processadores — considerando que o Spring Batch lê em chunk de tabelas transacionais grandes e que a API faz consultas de listagem simples.
- **Pool de conexões** e o impacto de N containers batch simultâneos sobre o PostgreSQL.

Registrar as descobertas em `docs/mapa/research/06-persistencia.md`.

## Answer

Pesquisa completa em [`../research/06-persistencia.md`](../research/06-persistencia.md).

- **PostgreSQL 18 com minor fixa**: imagem `postgres:18.4-trixie` (manifesto com `linux/arm64/v8`), a mesma tag em produção, no Compose e nos testes. Suporte até 14/11/2030 e `uuidv7()` nativo para as chaves de execução/histórico. Fallback para 17 só se surgir extensão sem build para 18.
- **Colunas tipadas por padrão**: os "dados não estruturados" da descrição são os artefatos no MinIO (`.jrprint`, `.csv.gz`), não linhas de banco — o dataset não se replica no PostgreSQL. `jsonb` fica restrito a `parametros_entrada` e `detalhe_erro`; índice só quando a consulta existir (coluna gerada `STORED` + B-tree, ou GIN `jsonb_path_ops` para containment).
- **Flyway na versão do BOM do Spring Boot (12.4.0)**, com `flyway-database-postgresql`; **uma instância por natureza de schema** (transacional por produto, controle, JobRepository), cada uma com seu `locations`, `defaultSchema` e tabela de histórico própria; `baselineOnMigrate=false` em todos os ambientes; `afterMigrate.sql` apenas para `GRANT`s idempotentes. JobRepository migrado pelo Flyway com `spring.batch.jdbc.initialize-schema=never`.
- **Acesso a dados**: `JdbcClient` na API e nas queries de relatório; Spring Data JPA só no CRUD administrativo; jOOQ não agora (exige geração de código no build de cada módulo). Leitura em chunk com `JdbcPagingItemReader` — `JdbcCursorItemReader` depende de quatro condições do pgjdbc e degrada **em silêncio** para carregar o ResultSet inteiro em memória.
- **Pool pequeno com orçamento explícito**: ~4 conexões por pool no batch (dois pools por container), ~10 na API, total ~68 de `max_connections=100`; o botão real é o paralelismo da DAG no Airflow, cujo banco de metadados fica em instância separada. PgBouncer só se o paralelismo crescer.
- **Isolamento por credencial, não por convenção**: `CREATE SCHEMA ... AUTHORIZATION`, `public` fora do `search_path`, `ALTER DEFAULT PRIVILEGES`, e usuário de migração com DDL separado do de runtime via `spring.flyway.url/user/password`.
- Repassado a outros tickets: DDL e GRANTs concretos → 04; tag do Testcontainers e o caso contra o H2 → 09; paralelismo da DAG → 13/19; ambiguidade "chave ausente vs nula" no CSV → 23.

## Notas do ticket 48 (deploy e runbook)

- **As migrações ganharam uma restrição que vem do deploy, não do banco**: toda migração é **aditiva e
  compatível com a imagem anterior** — coluna nova sempre nula, nunca `DROP` nem rename no mesmo
  release. É o que substitui um procedimento de rollback, já que o Flyway não desfaz e o deploy é
  roll-forward.
- **Renomear coluna vira dança de dois releases**: adiciona a nova e escreve nas duas; só no seguinte
  remove a antiga.
- **A ordem no deploy é fixa**: Flyway por natureza de schema **antes** do `--publicar-inventario`, que
  escreve em `jrxml_publicado`.
