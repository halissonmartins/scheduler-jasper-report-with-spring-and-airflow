# 22 — Observabilidade: OTLP, Collector e dashboards

**What to build:** A Operação passa a acompanhar a saúde do sistema em um lugar. Como os containers de Coleta são efêmeros e não podem ser raspados, eles empurram métricas para um Collector sempre ativo, que alimenta os dashboards de execuções, alertas, falhas e latência de geração.

**Blocked by:** 06 — Metadados, Status de Processamento e alerta por Tempo Estimado; 10 — Geração síncrona em CSV com contagem prévia.

**Status:** ready-for-agent

- [ ] Processadores exportam métricas por OTLP para um OpenTelemetry Collector sempre ativo (decidido na sessão; scraping é impossível em container efêmero)
- [ ] A API expõe suas métricas de latência de geração, erros e recusas por limite
- [ ] Dashboard mostra Execuções de Coleta por status, duração e contagem de linhas
- [ ] Dashboard evidencia execuções em processado com alerta e em processado com erro
- [ ] Nenhuma linha de dado de Relatório trafega em métrica, log ou telemetria
- [ ] Collector configurado no Compose junto com o backend de métricas e o Grafana
