# 29 — Migração de esquema com Flyway

**What to build:** O esquema do PostgreSQL passa a ter dono. As oito tabelas do spec e as do Spring Batch nascem de SQL versionado, aplicado no boot, igual em máquina de desenvolvedor, em Testcontainer e em produção (ADR-0020).

**Blocked by:** nenhum — é pré-requisito de 02, 03, 05, 06 e 12.

**Status:** ready-for-agent

- [ ] Flyway aplica as migrations no boot da API; o DDL oficial do Spring Batch entra como primeira migration, não por criação automática
- [ ] JPA sobe com `ddl-auto=validate` — o ORM valida o esquema e nunca o altera
- [ ] Testcontainers do seam 1 e do seam 2 sobem o esquema pelas mesmas migrations, sem DDL de teste paralelo
- [ ] Migration inicial cria as tabelas do spec: `produto`, `relatorio`, `role_relatorio`, `role_relatorio_relatorio`, `execucao_coleta`, `publicacao_relatorio`, `auditoria_geracao`
- [ ] Índice único de `publicacao_relatorio` por (Data de Referência, produto, código), que é o ponteiro do ADR-0006
- [ ] Cenário que sobe a aplicação contra banco vazio e contra banco já migrado, provando idempotência
- [ ] Runbook registra que atualizar a versão do Spring Batch exige revisar o DDL dele como nova migration (ADR-0020)
