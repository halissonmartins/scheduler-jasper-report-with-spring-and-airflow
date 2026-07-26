# Logs estruturados e tracing distribuído com Jaeger e Loki

Todo log de API e processador é JSON estruturado com `traceId` e `spanId` no MDC, produzidos por Micrometer Tracing. O OpenTelemetry Collector que já existe passa a ter **três** pipelines: métricas para o Prometheus, traces para o **Jaeger** (armazenamento Badger local, TTL de 7 dias) e logs para o **Loki** (modo monolítico, storage em filesystem, retenção de 7 dias pelo compactor). O contexto W3C `traceparent` é propagado do Angular para a API e do Airflow para dentro do container do processador.

Loki entra porque sem ele a decisão de log estruturado não se completa: JSON bonito no stdout de um container que o `DockerOperator` encerra morre com o container — exatamente a efemeridade que justificou o Collector para métricas. O par Loki + Grafana também é o que liga log e trace pelo `traceId` em um clique, que é o valor real de ter os dois.

**Nenhuma interface do plano de telemetria — Jaeger, Grafana, Prometheus — é publicada na internet.** Todas escutam apenas na rede interna, ao lado do Airflow (ADR-0009). Loki não tem interface própria: quem lê log lê pelo Grafana, e é por isso que a fronteira precisa valer para o Grafana também — deixá-lo público tornaria o resto decorativo, já que uma consulta LogQL alcança o log de qualquer Relatório sem passar por Role de Relatório.

Amostragem é integral: o volume é de execuções de Coleta agendadas e gerações sob demanda, não de tráfego web contínuo. Amostrar aqui perderia justamente o evento raro que se quer investigar.

Registrado porque o desenho anterior tinha uma assimetria não intencional: reconheceu que containers efêmeros não podem ser raspados e resolveu isso para métricas (Collector sempre ativo), mas deixou logs e traces sem decisão alguma. O ADR-0004 aceita OOM na API como risco; sem span em voo, o caso que o próprio ADR previu era o único a não deixar rastro, porque um OOM mata a JVM antes do commit da linha de desfecho em `auditoria_geracao`.

## Considered Options

- **Somente correlação, sem backend de traces** — `traceId` no MDC e nada armazenado. Mais barato, zero container novo, e cobre a maior parte do diagnóstico via log. Recusada: sem waterfall não se vê onde o tempo foi gasto dentro de uma geração, que é a pergunta do ADR-0004.
- **Grafana Tempo** — integra melhor com o Grafana já presente. Não escolhido; Jaeger foi preferido pela operação mais simples em nó único.
- **Elasticsearch/Cassandra como storage do Jaeger** — recusados: mais um sistema com estado para operar artesanalmente, contra o espírito do ADR-0009. Badger é embutido e suficiente para nó único.
- **Elasticsearch + Kibana / OpenSearch para logs** — recusados pelo mesmo motivo: JVM, sharding e tuning de cluster para um volume que cabe folgado em nó único, e uma segunda UI para operar e proteger.
- **Sem agregação de log** (`json-file` do Docker, leitura por `docker logs`) — recusada: não sobrevive ao container efêmero da Coleta, que é o caso em que o log mais importa.
- **Telemetria no ingress público atrás do Keycloak** — recusada. Seria coerente com o ADR-0010, mas o Keycloak autentica sem autorizar por Relatório: log e trace atravessam todos os Produtos, e não existe Role de Relatório aplicável a uma consulta LogQL.

## Consequências

- **Amplia o risco aceito do ADR-0016.** Log estruturado tem mais campos, mais retenção e menos controle de acesso que o banco. Por isso fica decidido: atributos de span e campos de log carregam apenas identificadores de domínio (`codigoRelatorio`, `dataReferencia`, `runId`, usuário) — **nunca** valor de linha de Relatório. É restrição verificável, não recomendação.
- Mais **dois** containers com estado no Compose (ADR-0009): Jaeger e Loki entram no runbook, na rotina de backup e no teste de restauração, todos artesanais.
- **Segunda exceção deliberada ao ADR-0010**, depois do Airflow. A justificativa é diferente da daquele: o Airflow ficou interno por ser execução remota de código; o plano de telemetria fica interno por agregar dado de todos os Produtos sem qualquer fronteira de Role de Relatório. Sob o ADR-0016 — que aceita CPF em mensagem de exceção — uma UI de log pública seria o caminho mais curto até dado pessoal.
- Operação passa a depender de rede interna ou túnel para ver dashboards, logs e traces. É custo de conveniência real, todo dia, não só no incidente.
- Traces são diagnóstico, não trilha de auditoria. Expiram em 7 dias junto com os dados (ADR-0008); a `auditoria_geracao` sobrevive muito além disso e continua sendo a fonte para pedidos de auditoria.
- Badger é nó único, sem HA: perder o volume do Jaeger perde o histórico de traces. Aceitável — não é dado de negócio.
- O `runId` continua sendo o correlator de **negócio** da Execução de Coleta; o `traceId` é o correlator **técnico**. São identificadores distintos com ciclos de vida distintos, e o `runId` deve aparecer como atributo de span para amarrar um ao outro.
