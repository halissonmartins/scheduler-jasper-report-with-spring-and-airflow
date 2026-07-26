# 27 — Logs estruturados e tracing distribuído

**What to build:** Uma falha passa a ser investigável sem acesso ao container. Todo log vira JSON com `traceId`/`spanId`, os spans chegam ao Jaeger pelo Collector já existente, e uma requisição do navegador ou uma DAG do Airflow pode ser seguida de ponta a ponta (ADR-0017).

**Blocked by:** 22 — Observabilidade: OTLP, Collector e dashboards (estabelece o Collector e o Compose de telemetria).

**Status:** ready-for-agent

- [ ] API e processadores emitem log JSON estruturado com `traceId` e `spanId` no MDC (Micrometer Tracing)
- [ ] Collector com três pipelines: métricas para o Prometheus, traces para o Jaeger, logs para o Loki
- [ ] Jaeger no Compose com storage Badger em volume persistente e TTL de spans vindo de parâmetro próprio, padrão 14 dias (ADR-0018)
- [ ] Loki no Compose em modo monolítico, storage em filesystem, retenção habilitada no compactor e vinda de parâmetro próprio, padrão 14 dias (ADR-0018)
- [ ] Log da Coleta continua consultável no Loki depois que o container do processador é encerrado — é o caso que motivou a agregação
- [ ] Grafana com datasource do Loki e salto de log para trace pelo `traceId`, sem copiar identificador à mão
- [ ] Jaeger, Grafana e Prometheus escutam apenas na rede interna, sem regra de ingress, ao lado do Airflow (ADR-0017)
- [ ] Amostragem integral, sem descarte de traces
- [ ] Frontend propaga `traceparent` W3C na chamada de geração; o trace resultante mostra a requisição do navegador e o trabalho na API no mesmo waterfall
- [ ] Airflow injeta o contexto de trace no container do processador, e a Execução de Coleta aparece como trace único do lançamento à troca de ponteiro
- [ ] `runId` presente como atributo de span, amarrando o correlator de negócio ao técnico
- [ ] Span de geração carrega código do Relatório, Data de Referência, formato e contagem de linhas — os dados que faltam quando a API morre por OOM (ADR-0004)
- [ ] Cenário que gera um Relatório e afirma que nenhum valor de linha aparece em log, span ou métrica (ADR-0016, ADR-0017)
- [ ] Log e trace do caminho de erro: geração recusada por limite e Coleta que falha no meio produzem trace com status de erro, não silêncio
