# Logs estruturados e tracing distribuído com Jaeger

Todo log de API e processador é JSON estruturado com `traceId` e `spanId` no MDC, produzidos por Micrometer Tracing. Os spans são exportados por OTLP para o OpenTelemetry Collector que já existe, que passa a ter dois pipelines: métricas para o Prometheus e traces para o **Jaeger**, com armazenamento Badger local e TTL de 7 dias. O contexto W3C `traceparent` é propagado do Angular para a API e do Airflow para dentro do container do processador.

Amostragem é integral: o volume é de execuções de Coleta agendadas e gerações sob demanda, não de tráfego web contínuo. Amostrar aqui perderia justamente o evento raro que se quer investigar.

Registrado porque o desenho anterior tinha uma assimetria não intencional: reconheceu que containers efêmeros não podem ser raspados e resolveu isso para métricas (Collector sempre ativo), mas deixou logs e traces sem decisão alguma. O ADR-0004 aceita OOM na API como risco; sem span em voo, o caso que o próprio ADR previu era o único a não deixar rastro, porque um OOM mata a JVM antes do commit da linha de desfecho em `auditoria_geracao`.

## Considered Options

- **Somente correlação, sem backend de traces** — `traceId` no MDC e nada armazenado. Mais barato, zero container novo, e cobre a maior parte do diagnóstico via log. Recusada: sem waterfall não se vê onde o tempo foi gasto dentro de uma geração, que é a pergunta do ADR-0004.
- **Grafana Tempo** — integra melhor com o Grafana já presente. Não escolhido; Jaeger foi preferido pela operação mais simples em nó único.
- **Elasticsearch/Cassandra como storage do Jaeger** — recusados: mais um sistema com estado para operar artesanalmente, contra o espírito do ADR-0009. Badger é embutido e suficiente para nó único.

## Consequências

- **Amplia o risco aceito do ADR-0016.** Log estruturado tem mais campos, mais retenção e menos controle de acesso que o banco. Por isso fica decidido: atributos de span e campos de log carregam apenas identificadores de domínio (`codigoRelatorio`, `dataReferencia`, `runId`, usuário) — **nunca** valor de linha de Relatório. É restrição verificável, não recomendação.
- Mais um container **com estado** no Compose (ADR-0009): entra no runbook, na rotina de backup e no teste de restauração, todos artesanais.
- Traces são diagnóstico, não trilha de auditoria. Expiram em 7 dias junto com os dados (ADR-0008); a `auditoria_geracao` sobrevive muito além disso e continua sendo a fonte para pedidos de auditoria.
- Badger é nó único, sem HA: perder o volume do Jaeger perde o histórico de traces. Aceitável — não é dado de negócio.
- O `runId` continua sendo o correlator de **negócio** da Execução de Coleta; o `traceId` é o correlator **técnico**. São identificadores distintos com ciclos de vida distintos, e o `runId` deve aparecer como atributo de span para amarrar um ao outro.
