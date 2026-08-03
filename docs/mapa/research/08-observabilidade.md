# 08 — Stack de observabilidade: topologia e biblioteca de log

Pesquisa de apoio ao ticket [`08-stack-observabilidade.md`](../issues/08-stack-observabilidade.md).
Todas as afirmações abaixo saem de fonte primária (documentação oficial ou README do próprio
componente). Onde a fonte não responde, está marcado como **lacuna**.

## Restrições que o projeto já impõe

De `docs/descricao-inicial.md` (regras arquiteturais), que valem como requisito e não como opinião:

- "Log, span, trace e métrica devem ser enviados para o OTel Collector" — o Collector é o **único
  ponto de saída** de telemetria da aplicação. Isso elimina, de saída, o caminho "app → Graylog via
  GELF direto" como caminho principal.
- "Correlation ID propagado automaticamente e formado por traceId nos logs via MDC permitindo a
  pesquisa no Graylog pelo Correlation ID".
- "SDK do OpenTelemetry é desabilitado para que os testes (JUnit/Cucumber/H2) não dependam de
  Collector nem gerem telemetria."
- "Sempre que possível usar as labels nome do produto e código do relatório nas métricas."
- "Produção roda Docker Compose em VMs" — sem service discovery de Kubernetes; alvos de scrape são
  estáticos.
- Dois perfis de processo muito diferentes: **API REST** (processo longo, porta 8080) e
  **processadores Spring Batch** (containers efêmeros disparados pelo Airflow). O que serve para um
  não serve necessariamente para o outro.

---

## 1. Log4j2 vs Logback no Spring Boot

### 1.1 Qual é o default e quanto custa trocar

Logback é o framework padrão quando se usam os starters do Spring Boot; o Boot inclui roteamento de
JUL, Commons Logging, Log4J e SLF4J para ele
([Spring Boot 3.5 — Logging](https://docs.spring.io/spring-boot/3.5/reference/features/logging.html)).

A troca em si é barata em Maven: excluir `spring-boot-starter-logging` de `spring-boot-starter` e
adicionar `spring-boot-starter-log4j2`
([Spring Boot 3.5 — How-to: Logging](https://docs.spring.io/spring-boot/3.5/how-to/logging.html)):

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter</artifactId>
  <exclusions>
    <exclusion>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-logging</artifactId>
    </exclusion>
  </exclusions>
</dependency>
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-log4j2</artifactId>
</dependency>
```

Num monorepo Maven com N módulos, a exclusão precisa ser repetida ou centralizada no POM pai — é
trabalho de configuração, não de arquitetura. O custo real não está aqui (ver 1.3).

### 1.2 Layout JSON estruturado: empate

Desde o Spring Boot 3.4 o *structured logging* é nativo e cobre os dois frameworks com os mesmos
três formatos — `ecs`, `gelf` e `logstash`
([Spring Boot 3.5 — Logging](https://docs.spring.io/spring-boot/3.5/reference/features/logging.html)):

```properties
logging.structured.format.console=gelf
logging.structured.format.file=gelf
```

Para configuração explícita, Logback usa `org.springframework.boot.logging.logback.StructuredLogEncoder`
e Log4j2 usa `<StructuredLogLayout format="..."/>` — mesma paridade funcional, mesma fonte.

**Conclusão:** em layout JSON estruturado (inclusive GELF, que é exatamente o formato do Graylog)
não há vencedor. O argumento clássico "Log4j2 tem JsonTemplateLayout, Logback precisa de
logstash-logback-encoder" caducou no Spring Boot 3.4+.

### 1.3 Integração com OpenTelemetry: aqui Logback ganha, com uma condição

Esta é a diferença decisiva, e ela **depende de qual mecanismo de instrumentação for escolhido**
(ver seção 4):

| Mecanismo | Logback | Log4j2 |
|---|---|---|
| **OTel Spring Boot starter** | Suporte pronto: `otel.instrumentation.logback-appender.enabled` (default `true`) e `otel.instrumentation.logback-mdc.enabled` (default `true`) ([out-of-the-box instrumentation](https://opentelemetry.io/docs/zero-code/java/spring-boot-starter/out-of-the-box-instrumentation/)) | **Não listado**. Exige adicionar o appender à mão no `log4j2.xml` ([additional instrumentations](https://opentelemetry.io/docs/zero-code/java/spring-boot-starter/additional-instrumentations/)) + o artefato `opentelemetry-log4j-context-data-2.17-autoconfigure` para o MDC ([README do módulo](https://github.com/open-telemetry/opentelemetry-java-instrumentation/blob/main/instrumentation/log4j/log4j-context-data/log4j-context-data-2.17/library-autoconfigure/README.md)) |
| **Java agent** | Logback 1.0+ | Log4j 2.7+ — mesma cobertura ([logger-mdc-instrumentation.md](https://github.com/open-telemetry/opentelemetry-java-instrumentation/blob/main/docs/logger-mdc-instrumentation.md)) |

Config manual necessária para Log4j2 com o starter
([fonte](https://opentelemetry.io/docs/zero-code/java/spring-boot-starter/additional-instrumentations/)):

```xml
<Configuration status="WARN" packages="io.opentelemetry.instrumentation.log4j.appender.v2_17">
  <Appenders>
    <OpenTelemetry name="OpenTelemetryAppender"/>
  </Appenders>
  <Loggers>
    <Root><AppenderRef ref="OpenTelemetryAppender" level="All"/></Root>
  </Loggers>
</Configuration>
```

### 1.4 Critério de decisão

- **Se a instrumentação for via OTel Spring Boot starter ou SDK** → **Logback**. Log4j2 custa dois
  artefatos e dois arquivos de configuração a mais por módulo, para entregar exatamente o mesmo
  resultado.
- **Se a instrumentação for via Java agent** → tanto faz do ponto de vista de OTel; aí o critério
  passa a ser desempenho (Log4j2 `AsyncLogger` com LMAX Disruptor) e o time decide por gosto. Como
  o volume de log deste projeto é de batch noturno + API REST de baixo QPS, o ganho de throughput
  do Log4j2 não paga a divergência do default do ecossistema Spring.

**Recomendação:** Logback. A entrada "Log4j2" da Tech Stack sugerida deve ser revista (ela está,
aliás, na lista "Pendentes de definição" do documento original: *"Definição da biblioteca de coleta
de log que será utilizada pelo Spring"*).

---

## 2. Caminho do log: Collector → Graylog, ou GELF direto?

### 2.1 O Collector **não** tem exporter GELF/Graylog

Inventário completo do diretório `exporter/` do
[opentelemetry-collector-contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter)
(47 exporters, consultado em 2026-08): não existe `gelfexporter` nem `graylogexporter`. Existem, e
são relevantes aqui, o `otlpexporter` (core), o `syslogexporter` e o `fileexporter`.

O `syslogexporter` envia logs em RFC5424/RFC3164 sobre TCP/UDP/unix socket
([README](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/exporter/syslogexporter/README.md)).
Ele monta a mensagem a partir de atributos do log record (`appname`, `hostname`, `message`,
`msg_id`, `priority`, `proc_id`, `structured_data`) — ou seja, exige um `transform`/`attributes`
processor no meio para mapear os campos, e o corpo estruturado tende a virar texto.

### 2.2 O Graylog tem input OTLP nativo — este é o caminho limpo

O Graylog expõe um **OpenTelemetry (gRPC) Input**
([documentação Graylog](https://go2docs.graylog.org/current/getting_in_log_data/opentelemetry__grpc__input.htm)),
que recebe OTLP/gRPC na porta 4317 e mapeia os campos OTel para o schema interno do Graylog. A
configuração no Collector é um `otlp` exporter comum:

```yaml
exporters:
  otlp/graylog:
    endpoint: "graylog:4317"
    tls:
      ca_file: /tls/rootCA.pem
service:
  pipelines:
    logs:
      exporters: [otlp/graylog]
```

**Limitações declaradas na própria doc** (citações):

- *"Only log data is supported. Metrics and traces transmitted over OTLP/gRPC are not ingested by this input."*
- *"The input exclusively accepts data over the gRPC transport. OTLP over HTTP is not supported."*
- Porta 4317, alinhada ao default OTLP/gRPC. TLS é opcional; há exemplos de TLS sem autenticação,
  TLS + bearer token e mTLS.

**Lacuna:** a documentação consultada é da linha Graylog 7.x (seletor mostra 7.1/7.0/6.3/6.2) e
**não diz** em qual versão o input foi introduzido nem se está disponível no Graylog Open. Isto
precisa ser verificado contra a versão exata que o `docker-compose.yml` for fixar, antes de a
topologia ser considerada fechada.

### 2.3 GELF direto: por que não como caminho principal

O Graylog aceita GELF por UDP, TCP e HTTP (porta padrão 12201, POST em `/gelf` no input HTTP)
([GELF inputs](https://go2docs.graylog.org/current/getting_in_log_data/gelf_inputs.html),
[formato GELF](https://go2docs.graylog.org/current/getting_in_log_data/gelf_format.html)), e o
Spring Boot já sabe emitir GELF nativamente (seção 1.2). Tecnicamente funciona e é o caminho de
menor esforço.

Mas ele viola a regra arquitetural "log, span, trace e métrica devem ser enviados para o OTel
Collector", e perde o benefício que justifica o Collector: enriquecimento, redação, *batching*,
*retry* com fila persistente e a possibilidade de trocar o backend sem tocar na aplicação.

### 2.4 Direto-ao-Collector (OTLP) vs stdout + `filelog` receiver

A especificação de logs do OTel compara os dois modelos
([OTel Logs spec](https://opentelemetry.io/docs/specs/otel/logs/)):

- **Direct-to-Collector (appender OTLP)**: formato formal e altamente estruturado; elimina
  *tailing*, parsing e rotação de arquivo; preserva correlação completa. Em contrapartida, exige
  conectividade de rede com o Collector e perde a conveniência de inspecionar o arquivo local.
- **Arquivo/stdout + `filelog` receiver**: pouca ou nenhuma mudança na aplicação, mantém o log local
  acessível, funciona com agentes de terceiros — ao custo de *"non-trivial log file reading and
  parsing functionality"* e de depender de um formato de saída bem definido.

Para este projeto o ponto sensível é o **container efêmero do Spring Batch**: se o Collector estiver
indisponível no momento em que o job termina e o container morre, o log direto-ao-Collector se
perde. Um `ConsoleAppender` em JSON estruturado mantido em paralelo (custo próximo de zero, já que o
Spring Boot faz isso com uma propriedade) é a rede de segurança — `docker logs` continua servindo
para diagnóstico local.

---

## 3. traceId e spanId no MDC, e o Correlation ID

### 3.1 Duas convenções de nomes de chave — e elas não são a mesma

Este é o detalhe que mais provavelmente vai gerar retrabalho se não for decidido agora.

| Origem | Chaves no MDC |
|---|---|
| Instrumentação OTel (agent, `logback-mdc`, `log4j-context-data`) | `trace_id`, `span_id`, `trace_flags` ([logger-mdc-instrumentation.md](https://github.com/open-telemetry/opentelemetry-java-instrumentation/blob/main/docs/logger-mdc-instrumentation.md)) |
| Micrometer Tracing / Spring Boot Actuator | `traceId`, `spanId` ([Spring Boot 3.5 — Tracing](https://docs.spring.io/spring-boot/3.5/reference/actuator/tracing.html)) |

O módulo `opentelemetry-log4j-context-data-2.17-autoconfigure` implementa o SPI `ContextDataProvider`
do Log4j2 (descoberto por ServiceLoader) e permite **customizar os nomes das chaves** via system
property / variável de ambiente; opcionalmente injeta *baggage* com prefixo `baggage.<entry_name>`
quando `otel.instrumentation.log4j-context-data.add-baggage` está ligado
([README](https://github.com/open-telemetry/opentelemetry-java-instrumentation/blob/main/instrumentation/log4j/log4j-context-data/log4j-context-data-2.17/library-autoconfigure/README.md)).

**Consequência prática:** o campo que o operador vai digitar na busca do Graylog muda conforme a
escolha. Ele precisa ser fixado em um único nome em todos os módulos, e esse nome precisa ser o
mesmo que aparece no corpo da mensagem de erro da API (regra de negócio: "Exibir mensagens de erro
no seguinte formato: horário do erro, descrição do erro, Correlation ID").

### 3.2 O padrão de correlação do Spring Boot

Quando se usa Micrometer Tracing, o Spring Boot já inclui os IDs no log por padrão, montados a
partir de `traceId` e `spanId` no MDC. O padrão é customizável
([Spring Boot 3.5 — Tracing](https://docs.spring.io/spring-boot/3.5/reference/actuator/tracing.html)):

```properties
logging.pattern.correlation=[${spring.application.name:},%X{traceId:-},%X{spanId:-}]
logging.include-application-name=false
```

Note o `:-` — o Logback substitui por string vazia quando a chave não existe. Ou seja, **sem span
ativo o log sai com o campo em branco, não com erro**. Isso confirma o diagnóstico da análise
comportamental (seção 5): o cenário Gherkin que valida Correlation ID falha silenciosamente, não
explode.

Há também a classe utilitária `CorrelationIdFormatter`, que formata a partir de uma spec
`traceId(32),spanId(16)` sobre um `Map` do MDC
([javadoc](https://docs.spring.io/spring-boot/3.5/api/java/org/springframework/boot/logging/CorrelationIdFormatter.html)).

### 3.3 O fallback é obrigatório (ticket 26)

Nenhuma fonte primária oferece um "gere um traceId quando não houver SDK". O comportamento
documentado é o contrário: sem span ativo, `Span.current().getSpanContext()` é o span context
inválido e o `trace_id` é a cadeia de zeros. Portanto o fallback é código de aplicação, e precisa
existir em três situações distintas:

1. **Testes** com tracing desligado (seção 5).
2. **Container Spring Batch** disparado pelo Airflow sem `traceparent` (seção 6).
3. **Falha do SDK / amostragem fora**.

A regra sugerida: um filtro/interceptor que (a) aceita o header `traceparent` recebido, (b) se não
houver span válido, gera um identificador próprio e o coloca no MDC sob a chave `correlationId`, e
(c) a mensagem de erro sempre lê `correlationId`, nunca `trace_id` diretamente. Assim o contrato da
API não depende do SDK estar ligado.

---

## 4. Micrometer × OTel: agent, starter ou SDK manual?

### 4.1 O que o Spring Boot autoconfigura — e o que não autoconfigura

Citação direta da referência do Actuator
([Spring Boot 3.5 — Observability](https://docs.spring.io/spring-boot/3.5/reference/actuator/observability.html)):

> *"Spring Boot does not provide auto-configuration for OpenTelemetry metrics or logging.
> OpenTelemetry tracing is only auto-configured when used in conjunction with Micrometer Tracing."*

Isso é decisivo: **`micrometer-tracing-bridge-otel` sozinho entrega trace, e só trace.** Ele não
liga o *log bridge* OTLP nem o *metrics* OTLP do SDK do OpenTelemetry. Métrica via OTLP no mundo
Spring vem de outro lugar — do `OtlpMeterRegistry` do Micrometer, configurado por
`management.otlp.metrics.export.url`
([Spring Boot 3.5 — Metrics](https://docs.spring.io/spring-boot/3.5/reference/actuator/metrics.html)).

### 4.2 As três combinações possíveis

| Opção | Trace | Métrica | Log (OTLP) | Custo |
|---|---|---|---|---|
| **A. Micrometer Tracing (bridge OTel) + `OtlpMeterRegistry`** | ✅ via bridge | ✅ via `management.otlp.metrics.export.url` | ❌ — precisa adicionar o appender OTel do OTel Java à mão | Baixo; tudo em `application.yml`, zero mudança no `docker run` |
| **B. OTel Spring Boot starter** | ✅ | ✅ (SDK) | ✅ (`logback-appender`) | Baixo; uma dependência. Ponte Micrometer→OTel existe mas vem **desligada** (`otel.instrumentation.micrometer.enabled` default `false`) ([fonte](https://opentelemetry.io/docs/zero-code/java/spring-boot-starter/out-of-the-box-instrumentation/)) |
| **C. Java agent (`-javaagent:opentelemetry-javaagent.jar`)** | ✅ | ✅ | ✅ | Mais instrumentação pronta, zero código; custo de startup e um artefato extra na imagem Docker ([agent getting started](https://opentelemetry.io/docs/zero-code/java/agent/getting-started/)) |

A doc do OTel posiciona os dois modos zero-code assim
([Spring Boot starter](https://opentelemetry.io/docs/zero-code/java/spring-boot-starter/)):

> *"You can instrument Spring Boot applications using either the OpenTelemetry Java agent, which
> offers more out-of-the-box instrumentation, or the OpenTelemetry Spring Boot starter."*

E recomenda o starter para *native image*, quando o overhead de startup do agent é preocupação, ou
quando já há outro agente de monitoramento em uso.

### 4.3 O overhead de startup importa aqui

Os processadores são **containers efêmeros**: sobem, rodam um job Spring Batch, morrem. Se o job
típico dura segundos a poucos minutos, os ~1–3 s de startup do Java agent viram percentual
relevante do tempo de execução — e o projeto tem uma regra de negócio que mede tempo de execução
contra um "tempo estimado" com margem de 100% para timeout duro. Ligar o agent muda o número
medido.

**Critério de decisão:** se o tempo estimado de execução dos jobs for da ordem de minutos, o
overhead é ruído e o agent é a opção mais simples (uma flag, cobre Log4j2 e Logback igualmente,
instrumenta JDBC/HTTP/Spring Batch sem código). Se houver jobs de poucos segundos, prefira o
**starter** (opção B), que também é o caminho que dá `logback-mdc` e `logback-appender` de graça.

---

## 5. Desabilitar o SDK nos testes: `otel.sdk.disabled` é a ferramenta errada

### 5.1 O que a propriedade faz, exatamente

- `otel.sdk.disabled=true` desabilita o SDK; `AutoConfiguredOpenTelemetrySdk#getOpenTelemetrySdk()`
  retorna *"a minimally configured instance"*
  ([Java configuration](https://opentelemetry.io/docs/languages/java/configuration/)).
- A variável equivalente `OTEL_SDK_DISABLED=true` faz o SDK ser substituído por uma implementação
  **no-op**, e — detalhe importante — *"This setting does not affect propagators configured via
  OTEL_PROPAGATORS"*
  ([SDK environment variables](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/)).
- Cuidado com um homônimo: na *declarative configuration* do Spring Boot starter a propriedade é
  `otel.disabled`, **não** `otel.sdk.disabled`
  ([SDK configuration do starter](https://opentelemetry.io/docs/zero-code/java/spring-boot-starter/sdk-configuration)).

Ou seja: o propagador continua extraindo `traceparent` de uma requisição de entrada, mas **nenhum
span é criado**, logo o `trace_id`/`traceId` no MDC fica vazio (ou zerado). Exatamente o que a
análise comportamental previu.

### 5.2 O Spring Boot já desliga tracing nos testes — mesmo sem essa propriedade

Isto tende a passar despercebido:

> *"When using the `@SpringBootTest` annotation, tracing components that report data are not
> automatically configured."*
> ([Spring Boot 3.5 — Tracing / Tests](https://docs.spring.io/spring-boot/3.5/reference/actuator/tracing.html))

E `@AutoConfigureObservability`, quando aplicada a um *sliced test*, adiciona *"an in-memory
`MeterRegistry`, a **no-op `Tracer`** and an `ObservationRegistry`"*
([javadoc](https://docs.spring.io/spring-boot/3.4/api/java/org/springframework/boot/test/autoconfigure/actuate/observability/AutoConfigureObservability.html)).
Ou seja, `@AutoConfigureObservability` **não resolve** o problema do MDC vazio: um `Tracer` no-op
também não gera trace ID válido.

Existe ainda `@ConditionalOnEnabledTracing`, que casa quando `management.tracing.enabled` é `true`
ou não está configurada, e `management.<name>.tracing.export.enabled`, que tem precedência sobre a
configuração global ([javadoc](https://docs.spring.io/spring-boot/3.5/api/java/org/springframework/boot/actuate/autoconfigure/tracing/ConditionalOnEnabledTracing.html)).

### 5.3 A alternativa correta: desligar o **exportador**, não o SDK

O requisito literal do documento é *"os testes não dependam de Collector nem gerem telemetria"*.
Isso é satisfeito por:

```properties
otel.traces.exporter=none
otel.metrics.exporter=none
otel.logs.exporter=none
```

Com o SDK **ligado** e todos os exportadores em `none`, o resultado é: span real criado, trace ID
válido, MDC preenchido, cenário Gherkin de Correlation ID passa — e **zero pacote de rede sai do
processo**. Nenhuma dependência de Collector. No caminho Spring/Micrometer o equivalente é manter
`management.tracing.enabled=true` e desligar apenas `management.<exporter>.tracing.export.enabled`.

**Trade-off honesto:** o SDK ligado tem custo de memória e de tempo de inicialização por contexto de
teste, e há mais uma peça que pode falhar na suíte. Se o time preferir a variante rígida
(`otel.sdk.disabled=true`), o preço é ter que implementar e testar o fallback de Correlation ID da
seção 3.3 — o que, aliás, é preciso fazer de qualquer forma por causa do caminho batch. Nesse caso
os cenários Gherkin devem validar o **formato e a presença** do `correlationId`, nunca que ele é
igual a um traceId de OTel.

Critério: se a suíte tiver poucos contextos Spring, use `exporter=none` (fidelidade maior ao
comportamento de produção). Se a suíte for grande e cara, use `otel.sdk.disabled=true` + fallback,
aceitando que o teste exercita o caminho degradado e não o caminho de produção.

---

## 6. Trace no batch e o papel do Airflow

O Airflow 3.3 emite traces OTel por configuração na seção `[traces]` — `otel_on`, `otel_host`,
`otel_port` (default `localhost:8889`), `otel_application`, `otel_ssl_active`, `otel_task_log_event`
— e a doc observa que o SDK deve ser configurado pelas variáveis padrão do OpenTelemetry, como
`OTEL_EXPORTER_OTLP_ENDPOINT`
([Airflow — Traces](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/traces.html)).
Spans customizados criados dentro de tasks são aninhados automaticamente sob o span da task.

**Lacuna importante:** a documentação do Airflow **não** trata da propagação do contexto para
processos externos lançados pela task. E do lado Java, ler `TRACEPARENT` de variável de ambiente é
uma **convenção do ecossistema**, não comportamento nativo do agent/SDK — a extração precisa ser
feita em código, via `propagator.extract(...)` sobre um getter que lê o ambiente
([OTel — instrumentando bibliotecas](https://opentelemetry.io/docs/concepts/instrumentation/libraries/)),
padrão usado por ferramentas como o
[opentelemetry-ext-cli-java](https://github.com/release-engineering/opentelemetry-ext-cli-java).

Isso vira uma pequena responsabilidade do **Starter do Processador** (ticket 21): na inicialização,
ler `TRACEPARENT` do ambiente, extrair o contexto e abrir o span raiz do job com esse pai. Sem isso,
não há correlação DAG run ↔ execução Spring Batch ↔ logs no Graylog.

---

## 7. Prometheus: scrape do actuator ou push pelo Collector?

### 7.1 O que o Prometheus diz sobre receber OTLP

O receptor OTLP existe (`--web.enable-otlp-receiver`, endpoint `POST /api/v1/otlp/v1/metrics`), mas
a própria documentação o desaconselha como caminho geral
([Prometheus — HTTP API](https://prometheus.io/docs/prometheus/latest/querying/api/),
[Prometheus — guia OpenTelemetry](https://prometheus.io/docs/guides/opentelemetry/)):

> *"This is not an efficient way of ingesting samples. Use it with caution for specific low-volume
> use cases. It is not suitable for replacing the ingestion via scraping."*

Está desabilitado por padrão porque o Prometheus pode rodar sem autenticação nenhuma.

### 7.2 O que o Collector oferece

- `prometheusexporter` — **expõe** um endpoint `/metrics` no próprio Collector para o Prometheus
  raspar. Opções relevantes: `namespace`, `const_labels`, `metric_expiration`, `send_timestamps`,
  `resource_to_telemetry_conversion`, `enable_open_metrics`
  ([README](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/exporter/prometheusexporter/README.md)).
- `prometheusremotewriteexporter` — **empurra** via remote write. Limitação citada literalmente:
  *"Non-cumulative monotonic, histogram, and summary OTLP metrics are dropped by this exporter."*
  ([README](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/exporter/prometheusremotewriteexporter/README.md)).
  Como as métricas de duração de job/exportação são naturalmente histogramas, isso é um problema
  real e não teórico.
- `prometheusreceiver` — o Collector também sabe **raspar** alvos Prometheus, com paridade
  declarada de projeto entre `app → prometheus → /metrics` e
  `app → otelcol(prometheus receiver) → otelcol(prometheus exporter) → /metrics`
  ([DESIGN.md](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/prometheusreceiver/DESIGN.md)).

### 7.3 O problema específico do container efêmero

O modelo pull do Prometheus não funciona para um container que vive alguns minutos: pode não haver
scrape antes de ele morrer, e o alvo é dinâmico. A resposta clássica — Pushgateway — é explicitamente
desaconselhada pela documentação ([Prometheus — pushing metrics](https://prometheus.io/docs/practices/pushing/)):

> *"The only valid use case for the Pushgateway is for capturing the outcome of a service-level
> batch job."*

com três problemas listados: ponto único de falha, perda da métrica `up` de saúde do scrape, e
*"The Pushgateway never forgets series pushed to it"* — séries obsoletas ficam para sempre salvo
remoção manual via API. Como o projeto quer labels de alta rotatividade (`produto`, `codigo_relatorio`)
por execução, isso apodrece rápido.

**O Collector com `prometheusexporter` resolve isso melhor que o Pushgateway**: os processadores
empurram OTLP para o Collector, o Collector mantém a série em memória por `metric_expiration` e a
expõe para scrape; passado o prazo, a série some sozinha. É o Pushgateway sem o defeito principal.

### 7.4 Temporalidade

O `OtlpMeterRegistry` do Micrometer usa `aggregationTemporality` com default `cumulative`,
controlável também por `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE`
([Micrometer — OTLP](https://github.com/micrometer-metrics/micrometer/blob/main/docs/modules/ROOT/pages/implementations/otlp.adoc)).
**Manter `cumulative`** — o Prometheus espera dados cumulativos que não reiniciam
([Micrometer — distribution summaries](https://github.com/micrometer-metrics/micrometer/blob/main/docs/modules/ROOT/pages/concepts/distribution-summaries.adoc)),
e o `prometheusremotewriteexporter` descarta métricas monotônicas não-cumulativas.

Para percentis agregáveis no Prometheus, usar `publishPercentileHistogram()` e **não**
`publishPercentiles()` (este último calcula no cliente e não agrega entre instâncias)
([Micrometer — histogramas e quantis](https://github.com/micrometer-metrics/micrometer/blob/main/docs/modules/ROOT/pages/concepts/histogram-quantiles.adoc)).

### 7.5 Cardinalidade

As labels pedidas pelo documento (`produto`, `codigo_relatorio`) geram dezenas de séries por
métrica — seguro. A análise comportamental já alerta: **não** incluir data de referência nem
identificador de usuário nas mesmas métricas. O `correlationId`/`traceId` **nunca** vira label de
métrica; ele vive no log e no trace, que é onde a alta cardinalidade é barata.

---

## 8. Traces: Jaeger aceita OTLP nativamente

O Jaeger v2 recebe OTLP em 4317 (gRPC) e 4318 (HTTP) direto no all-in-one
([README](https://github.com/jaegertracing/jaeger/blob/main/README.md)), e o
[`all-in-one.yaml`](https://github.com/jaegertracing/jaeger/blob/main/cmd/jaeger/internal/all-in-one.yaml)
confirma que o receiver `otlp` alimenta **apenas** o pipeline `traces` — não há pipeline de métricas.
Portanto: um `otlp` exporter no Collector apontando para o Jaeger, e nada de protocolo Jaeger nativo
ou Zipkin na aplicação.

**Colisão de portas a resolver no Compose:** Collector (4317), Jaeger (4317) e Graylog OTel input
(4317) querem a mesma porta padrão. Em rede Docker interna isso é resolvido por hostname
(`otel-collector:4317`, `jaeger:4317`, `graylog:4317`), mas nenhuma dessas portas pode ser publicada
no host simultaneamente sem remapeamento.

---

## Recomendação

### Decisões

1. **Biblioteca de log: Logback**, com structured logging nativo do Spring Boot
   (`logging.structured.format.console=ecs` ou `gelf`). Remover Log4j2 da Tech Stack, ou rebaixá-lo
   a "alternativa se adotarmos o Java agent".
2. **Instrumentação: OTel Spring Boot starter** (`io.opentelemetry.instrumentation:opentelemetry-spring-boot-starter`)
   como base — dá trace, métrica e log OTLP com uma dependência, e traz `logback-appender` +
   `logback-mdc` ligados por padrão. Manter `micrometer-tracing-bridge-otel` **apenas** se o time
   quiser a API de observação do Micrometer nas anotações; não é necessário para o pipeline.
   *Alternativa Java agent* aceitável se os jobs durarem minutos e o time preferir zero dependência
   de código.
3. **Logs vão para o Graylog via Collector, por OTLP/gRPC** (OpenTelemetry gRPC Input do Graylog),
   não por GELF direto e não por `syslogexporter`. Manter um `ConsoleAppender` JSON em paralelo como
   rede de segurança para `docker logs`.
4. **Métricas: push OTLP para o Collector; o Prometheus faz scrape do Collector** via
   `prometheusexporter`. Não usar Pushgateway; não usar o receptor OTLP do Prometheus; não usar
   `prometheusremotewriteexporter` (descarta histogramas). Temporalidade `cumulative`.
5. **Traces: OTLP para o Collector → OTLP para o Jaeger.**
6. **Nos testes: `otel.*.exporter=none` com o SDK ligado**, e não `otel.sdk.disabled=true`.
   Independentemente disso, implementar o fallback de `correlationId` (ticket 26), porque o caminho
   batch precisa dele de qualquer forma.
7. **Chaves de MDC:** fixar `trace_id` / `span_id` / `trace_flags` (convenção OTel, alinhada com
   ECS) em todos os módulos, e expor o valor de busca do Graylog como `correlationId` — um campo
   único, preenchido pelo traceId quando houver span e por um ID gerado quando não houver.

### Topologia

```
                        ┌──────────────────────────────────────────┐
                        │            Apache Airflow                │
                        │  [traces] otel_on = True                 │
                        │  DockerOperator: env TRACEPARENT=...     │
                        └───────┬──────────────────────┬───────────┘
                                │ OTLP (traces)        │ docker run
                                │                      ▼
                                │      ┌───────────────────────────────┐
                                │      │  Processador Spring Batch     │
                                │      │  (container efêmero)          │
                                │      │  OTel Spring Boot starter     │
                                │      │  Logback + logback-mdc        │
                                │      │  lê TRACEPARENT → span raiz   │
                                │      └───────────┬───────────────────┘
                                │                  │ OTLP (log+trace+métrica)
  ┌──────────────────────┐      │                  │
  │   API REST :8080     │      │                  │
  │  OTel SB starter     │──────┼──────────────────┤
  │  Logback + MDC       │ OTLP │                  │
  │  /actuator/health/*  │      │                  │
  └──────────────────────┘      ▼                  ▼
                        ┌──────────────────────────────────────────┐
                        │            OTel Collector                │
                        │  receivers: otlp (4317 gRPC / 4318 HTTP) │
                        │  processors: memory_limiter, resource,   │
                        │              transform, batch            │
                        │  ┌────────┬────────────┬───────────────┐ │
                        │  │ logs   │  traces    │   metrics     │ │
                        │  └───┬────┴─────┬──────┴───────┬───────┘ │
                        └──────┼──────────┼──────────────┼─────────┘
                               │          │              │
              otlp/graylog ────┘          │              └──── prometheus
              (gRPC :4317)                │                    (expõe /metrics :8889)
                               ┌──────────┘                          │
                               │ otlp (:4317)                        │ scrape
                               ▼                                     ▼
                 ┌──────────────────────┐                 ┌──────────────────────┐
   ┌─────────────┤   Jaeger  (:16686)   │                 │  Prometheus (:9090)  │
   │             └──────────────────────┘                 └──────────┬───────────┘
   │                                                                 │
   │   ┌──────────────────────┐                                      │
   └──►│  Graylog  (:9000)    │◄──── busca por correlationId         │
       │  OTel gRPC Input     │                                      │
       └──────────────────────┘                                      │
                                          ┌──────────────────────┐   │
                                          │   Grafana (:3000)    │◄──┘
                                          │  datasources:        │
                                          │  Prometheus + Jaeger │
                                          └──────────────────────┘
```

Fluxo de correlação, ponta a ponta: o Airflow gera o `traceparent` → injeta como env do container →
o Starter do Processador abre o span raiz com esse pai → `logback-mdc` põe `trace_id`/`span_id` em
todo log → o log sai por OTLP para o Collector → chega ao Graylog com o campo indexado → a mensagem
de erro da API expõe o mesmo valor como `correlationId` → o operador cola no Graylog e no Jaeger.

### Pendências para fechar antes de escrever o `docker-compose.yml`

- **Versão do Graylog** que tem o OpenTelemetry gRPC Input, e se ele existe na edição Open. Se não
  existir, o plano B é `syslogexporter` → Syslog TCP Input (perde estrutura) ou, aceitando exceção
  à regra arquitetural, GELF direto pelo `logging.structured.format`.
- **Remapeamento de portas 4317** entre Collector, Jaeger e Graylog no Compose.
- **`metric_expiration`** do `prometheusexporter` calibrado contra o intervalo de scrape e a duração
  típica dos jobs, para que métrica de job curto não expire antes de ser raspada.
- **Duração típica dos jobs**, que decide agent vs starter (seção 4.3).
