# 08 — Stack: observabilidade (OTel Collector, Prometheus, Jaeger, Graylog, lib de log)

Type: research
Status: resolved
Blocked by: —

## Question

Qual a topologia de observabilidade, e qual biblioteca de log?

A stack sugerida lista OpenTelemetry (Micrometer), OTel SDK, OTel Collector, Prometheus, Grafana, Graylog, Jaeger e Log4j2 — com sobreposição real entre os caminhos. E "definição da biblioteca de coleta de log" é pendência explícita, enquanto o default do Spring Boot é Logback.

Levantar com fontes primárias (use context7) e recomendar:

- **Log4j2 vs Logback** no Spring Boot: qual escolher, o custo de trocar o default, e qual tem melhor suporte a layout JSON estruturado e a appender OTLP.
- **Caminho do log**: aplicação → OTel Collector via OTLP → Graylog, ou aplicação → Graylog via GELF direto? O documento exige que log, span, trace e métrica vão para o Collector. Levantar se o Collector consegue exportar para Graylog e como.
- **traceId e spanId no MDC**: como o OTel injeta automaticamente, e como isso alimenta o Correlation ID (ticket 26).
- **Micrometer × OTel**: `micrometer-tracing-bridge-otel` vs o agente Java do OTel vs o SDK manual. Qual combinação entrega métrica no Prometheus e trace no Jaeger pelo Collector.
- **Desabilitar o SDK nos testes**: qual a propriedade correta (`otel.sdk.disabled`) e o que ela quebra — a análise comportamental aponta que sem SDK o MDC fica vazio e cenários Gherkin que validam Correlation ID falham.
- **Prometheus vs OTLP metrics**: scrape do actuator ou push pelo Collector.

Registrar as descobertas em `docs/mapa/research/08-observabilidade.md`.

## Answer

Pesquisa completa em [`../research/08-observabilidade.md`](../research/08-observabilidade.md).

- **Log: Logback, não Log4j2.** Desde o Spring Boot 3.4 o structured logging nativo (`ecs`, `gelf`, `logstash`) cobre os dois igualmente, então JSON deixou de ser critério. O desempate é OTel: o Spring Boot starter do OpenTelemetry traz `logback-appender` e `logback-mdc` ligados por padrão e **não lista Log4j2** — que exigiria appender manual no `log4j2.xml` mais o artefato `opentelemetry-log4j-context-data-2.17-autoconfigure`. Com Java agent os dois empatam; sem agent, Logback.
- **Caminho do log: app → OTLP → Collector → Graylog.** Não existe exporter GELF/Graylog no collector-contrib (47 exporters verificados), mas o **Graylog tem um OpenTelemetry gRPC Input** (OTLP/gRPC :4317, só logs, sem HTTP) — logo um `otlp` exporter comum resolve, sem violar a regra "tudo passa pelo Collector". Manter console JSON em paralelo como rede de segurança. Pendência: confirmar a versão/edição do Graylog que tem esse input.
- **MDC:** OTel injeta `trace_id`/`span_id`/`trace_flags`; Micrometer/Spring usa `traceId`/`spanId`. São convenções diferentes — fixar uma e expor sempre um campo único `correlationId`.
- **`otel.sdk.disabled=true` é a ferramenta errada nos testes.** Ele produz um SDK no-op (não afeta propagadores), e o `@SpringBootTest` do Spring já substitui o Tracer por no-op mesmo com `@AutoConfigureObservability` — em ambos os casos o MDC fica vazio. Preferir **`otel.traces/metrics/logs.exporter=none` com o SDK ligado**: span real, MDC preenchido, zero rede, zero Collector. O fallback de Correlation ID (ticket 26) continua obrigatório por causa do caminho batch.
- **Métricas: push OTLP para o Collector, e o Prometheus faz scrape do Collector** (`prometheusexporter`). O receptor OTLP do Prometheus é desaconselhado pela própria doc ("not suitable for replacing ingestion via scraping"), o Pushgateway "never forgets series" e o `prometheusremotewriteexporter` **descarta histogramas e summaries**. Temporalidade `cumulative`.
- **Traces:** Jaeger v2 recebe OTLP nativo em 4317/4318 — Collector → `otlp` → Jaeger. Atenção à colisão da porta 4317 entre Collector, Jaeger e Graylog no Compose.
- **Batch/Airflow:** o Airflow 3.3 emite traces via `[traces] otel_on`, mas **não propaga contexto para processos externos**; e o agent/SDK Java não lê `TRACEPARENT` de env automaticamente. Extrair o contexto em código vira responsabilidade do Starter do Processador (ticket 21).
