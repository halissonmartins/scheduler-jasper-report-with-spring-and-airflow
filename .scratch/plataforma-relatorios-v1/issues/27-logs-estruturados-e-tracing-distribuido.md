# 27 — Logs estruturados e tracing distribuído

**What to build:** Uma falha passa a ser investigável sem acesso ao container. Todo log vira JSON com `traceId`/`spanId`, os spans chegam ao Jaeger pelo Collector já existente, e uma requisição do navegador ou uma DAG do Airflow pode ser seguida de ponta a ponta (ADR-0017).

**Blocked by:** 22 — Observabilidade: OTLP, Collector e dashboards (estabelece o Collector e o Compose de telemetria).

**Status:** ready-for-agent

- [ ] API e processadores emitem log JSON estruturado com `traceId` e `spanId` no MDC (Micrometer Tracing)
- [ ] Collector com dois pipelines: métricas para o Prometheus, traces para o Jaeger
- [ ] Jaeger no Compose com storage Badger em volume persistente e TTL de spans de 7 dias (ADR-0008)
- [ ] Amostragem integral, sem descarte de traces
- [ ] Frontend propaga `traceparent` W3C na chamada de geração; o trace resultante mostra a requisição do navegador e o trabalho na API no mesmo waterfall
- [ ] Airflow injeta o contexto de trace no container do processador, e a Execução de Coleta aparece como trace único do lançamento à troca de ponteiro
- [ ] `runId` presente como atributo de span, amarrando o correlator de negócio ao técnico
- [ ] Span de geração carrega código do Relatório, Data de Referência, formato e contagem de linhas — os dados que faltam quando a API morre por OOM (ADR-0004)
- [ ] Cenário que gera um Relatório e afirma que nenhum valor de linha aparece em log, span ou métrica (ADR-0016, ADR-0017)
- [ ] Log e trace do caminho de erro: geração recusada por limite e Coleta que falha no meio produzem trace com status de erro, não silêncio
