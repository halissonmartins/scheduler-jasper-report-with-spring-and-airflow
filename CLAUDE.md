# scheduler-jasper-report-with-spring-and-airflow

Coletor agendado de dados de relatórios (Spring Batch, orquestrado pelo Airflow) e gerador sob demanda desses relatórios em PDF/CSV/XLSX/DOCX (Jasper Reports), com API REST e frontend Angular.

Comece por [`CONTEXT.md`](./CONTEXT.md) (glossário) e por [`docs/adr/`](./docs/adr/) (decisões). A descrição inicial em `docs/descricao-inicial.txt` é histórica: onde ela divergir dos ADRs, os ADRs vencem — em particular, sua linha 32 foi revogada (ADR-0007).

## Agent skills

### Issue tracker

Issues e specs vivem como arquivos markdown em `.scratch/<feature-slug>/` neste repositório. See `docs/agents/issue-tracker.md`.

### Triage labels

Os cinco papéis canônicos de triagem, escritos como valor da linha `Status:` dentro de cada arquivo de issue. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` na raiz. See `docs/agents/domain.md`.

## Convenções

- **Idioma**: identificadores de domínio em pt-BR (`Relatorio`, `RoleDeRelatorio`, `StatusProcessamento`), andaime técnico em inglês (`Repository`, `Controller`, `Config`). Docs de domínio em pt-BR. Ver ADR-0012.
- **Build**: agregador Maven único na raiz, versão compartilhada, tudo liberado junto. Ver ADR-0001. Use `./mvnw` quando existir.
- **Stack**: Java 25 (Temurin), Spring Boot 4.1.x (mínimo Java 17, suporta até Java 26), Spring Batch 6.x, Jasper Reports, PostgreSQL, MongoDB, Keycloak, Airflow, OpenTelemetry Collector + Prometheus/Grafana + Jaeger, Angular. Sem Json Server — o cliente Angular é gerado do OpenAPI.
- **Testes**: Cucumber/Gherkin em todas as camadas, inclusive Coleta, contra Testcontainers; JUnit para TDD interno. Cenários de batch etiquetados e rodados em etapa própria de CI. Ver ADR-0013.

## Antes de "consertar" algo

ADR-0004, ADR-0009, ADR-0010, ADR-0014 e ADR-0016 registram **riscos aceitos**, não designs ideais — geração síncrona sem bulkhead, Compose em VMs, exposição pública sem MFA, senha inicial do ADMINISTRADOR sem rotação, ausência de classificação de dados. Foram debatidos e escolhidos deliberadamente. Se for propor mudança, cite o ADR e o que mudou no contexto.
