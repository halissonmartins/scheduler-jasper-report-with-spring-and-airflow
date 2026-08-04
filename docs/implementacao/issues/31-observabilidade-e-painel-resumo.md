# 31 — Observabilidade e painel-resumo

**O que construir:** o lugar onde alguém descobre que algo está errado. Como **nenhum alerta
notifica ninguém** — decisão registrada, com o efeito composto que ela produz —, o painel-resumo
deixa de ser organização visual e vira o mecanismo que sustenta três contenções escritas em outros
pontos.

**Bloqueado por:** 09, 17.

**Status:** ready-for-agent

**Critérios de aceitação**

- [ ] Collector recebendo log, trace e métrica; Prometheus fazendo scrape do Collector; Jaeger
      recebendo trace; Graylog recebendo log pelo input OpenTelemetry. Atenção à colisão de porta
      entre os três no Compose.
- [ ] Logs estruturados com traceId e spanId, pesquisáveis pelo mesmo Correlation ID que o usuário vê
      na tela de erro.
- [ ] O catálogo de métricas da API emitindo: duração de exportação **por formato** (medi-las juntas
      esconde a diferença que importa para dimensionar heap), ocupação e espera do semáforo, recusas,
      downloads, downloads após a data de expurgo com os **dois** desfechos, e erros por código.
- [ ] Métricas de capacidade: ocupação do bucket, contagem de linhas por tabela, transições de
      readiness e contagem de séries.
- [ ] **O painel-resumo é o destino padrão** de quem abre o Grafana, e responde "algo precisa de
      atenção agora?" em dez segundos: encerramento perdido, alerta recorrente, artefato acima do
      teto, Execuções fechadas pela varredura, Coletas do dia, idade da varredura e contagem de
      séries.
- [ ] A contagem de séries está no painel porque a guarda de cardinalidade é **documental**: é o
      único lugar onde um label indevido apareceria antes de o Prometheus degradar.
- [ ] Os alertas existem e pintam o painel. **Ninguém é notificado** — está registrado como risco
      aceito, e o painel é a contenção.
- [ ] Erro de batch é métrica **separada** da de API, porque os dois têm vocabulários distintos —
      juntá-las faria o mesmo label carregar valores de dois catálogos.
