# 31 — Pipeline de CI

**What to build:** A "etapa própria de CI" que quatro documentos citam e nenhum ticket constrói. GitHub Actions em runners x86, com os seams lentos separados do fluxo de cada push (ADR-0013, ADR-0020).

**Blocked by:** 23 — E2E Playwright incluindo o teto de blob; 29 — Migração de esquema com Flyway.

**Status:** ready-for-agent

- [ ] Build Maven do agregador e cenários do seam 1 rodam a cada push
- [ ] Cenários de batch (seam 2) e E2E de navegador (seam 4) rodam em etapas próprias, por etiqueta, fora do fluxo de cada push (ADR-0013)
- [ ] Testes de geração de DAG (seam 3, pytest) rodam junto com o seam 1 — são rápidos
- [ ] Cliente Angular gerado do OpenAPI no build do frontend; divergência entre contrato e cliente committado quebra a build (ADR-0020)
- [ ] Runbook registra que CI roda em x86 e produção em ARM64, e o que essa diferença não cobre
